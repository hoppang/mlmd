package httpapi

import (
	"context"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"io/fs"
	"log/slog"
	"net/http"
	"regexp"
	"strconv"
	"strings"
	"time"

	"github.com/hoppang/mlmd/server/internal/auth"
	"github.com/hoppang/mlmd/server/internal/backupstatus"
	"github.com/hoppang/mlmd/server/internal/model"
	"github.com/hoppang/mlmd/server/internal/store"
)

const (
	protocolVersion          = 1
	defaultLimit             = 200
	maxIncoming              = 200
	maxOutgoing              = 100
	maxCiphertextBytes       = 256 * 1024
	maxRequestBytes    int64 = 2 * 1024 * 1024
)

var uuidPattern = regexp.MustCompile(`^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$`)

type Server struct {
	store              store.Store
	logger             *slog.Logger
	bootstrapTokenHash [32]byte
	backupStatusPath   string
	handler            http.Handler
}

func New(serverStore store.Store, bootstrapToken string, logger *slog.Logger, backupStatusPath string) *Server {
	if logger == nil {
		logger = slog.Default()
	}
	s := &Server{
		store:              serverStore,
		logger:             logger,
		bootstrapTokenHash: sha256.Sum256([]byte(bootstrapToken)),
		backupStatusPath:   backupStatusPath,
	}
	mux := http.NewServeMux()
	mux.HandleFunc("GET /v1/health/live", s.handleLive)
	mux.HandleFunc("GET /v1/health/ready", s.handleReady)
	mux.HandleFunc("GET /v1/health/backup", s.handleBackupHealth)
	mux.HandleFunc("POST /v1/bootstrap/spaces", s.handleBootstrapSpace)
	mux.HandleFunc("POST /v1/spaces/{spaceId}/invites", s.handleCreateInvite)
	mux.HandleFunc("POST /v1/invites/{inviteId}/consume", s.handleConsumeInvite)
	mux.HandleFunc("GET /v1/spaces/{spaceId}/devices", s.handleListDevices)
	mux.HandleFunc("DELETE /v1/spaces/{spaceId}/devices/{deviceId}", s.handleRevokeDevice)
	mux.HandleFunc("POST /v1/spaces/{spaceId}/exchange", s.handleExchange)
	s.handler = s.recoverAndLog(mux)
	return s
}

type createInviteRequest struct {
	Role string `json:"role"`
}

type createInviteResponse struct {
	InviteID          string    `json:"inviteId"`
	FamilySpaceID     string    `json:"familySpaceId"`
	InviteToken       string    `json:"inviteToken"`
	Role              string    `json:"role"`
	ExpiresAt         time.Time `json:"expiresAt"`
	CreatedByDeviceID string    `json:"createdByDeviceId"`
}

func (s *Server) handleCreateInvite(w http.ResponseWriter, r *http.Request) {
	device, err := s.authenticate(r)
	if !s.authorizeSpaceRequest(w, r, device, err) {
		return
	}
	var request createInviteRequest
	if err := decodeJSON(w, r, &request); err != nil {
		writeDecodeError(w, err)
		return
	}
	if request.Role == "" {
		request.Role = "member"
	}
	if request.Role != "owner" && request.Role != "member" {
		writeError(w, http.StatusBadRequest, "invalid_role")
		return
	}
	secret, tokenHash, err := auth.NewSecret()
	if err != nil {
		s.internalError(w, err)
		return
	}
	expiresAt := time.Now().UTC().Add(10 * time.Minute)
	invite, err := s.store.CreateInvite(r.Context(), device.FamilySpaceID, device.ID, request.Role, tokenHash, expiresAt)
	if errors.Is(err, store.ErrForbidden) {
		writeError(w, http.StatusForbidden, "owner_required")
		return
	}
	if err != nil {
		s.internalError(w, err)
		return
	}
	writeJSON(w, http.StatusCreated, createInviteResponse{
		InviteID: invite.ID, FamilySpaceID: invite.FamilySpaceID,
		InviteToken: invite.ID + "." + secret, Role: invite.Role,
		ExpiresAt: invite.ExpiresAt, CreatedByDeviceID: invite.CreatedByDeviceID,
	})
}

type consumeInviteRequest struct {
	InviteToken       string `json:"inviteToken"`
	DeviceID          string `json:"deviceId"`
	DeviceDisplayName string `json:"deviceDisplayName"`
	DeviceSecret      string `json:"deviceSecret"`
}

type consumeInviteResponse struct {
	FamilySpaceID string    `json:"familySpaceId"`
	DeviceID      string    `json:"deviceId"`
	Role          string    `json:"role"`
	DisplayName   string    `json:"displayName"`
	CreatedAt     time.Time `json:"createdAt"`
}

func (s *Server) handleConsumeInvite(w http.ResponseWriter, r *http.Request) {
	inviteID := r.PathValue("inviteId")
	if !uuidPattern.MatchString(inviteID) {
		writeError(w, http.StatusNotFound, "invite_not_found")
		return
	}
	var request consumeInviteRequest
	if err := decodeJSON(w, r, &request); err != nil {
		writeDecodeError(w, err)
		return
	}
	request.DeviceDisplayName = strings.TrimSpace(request.DeviceDisplayName)
	if !uuidPattern.MatchString(request.DeviceID) || request.DeviceDisplayName == "" || len([]rune(request.DeviceDisplayName)) > 100 {
		writeError(w, http.StatusBadRequest, "invalid_request")
		return
	}
	deviceSecretBytes, err := base64.RawURLEncoding.DecodeString(request.DeviceSecret)
	if err != nil || len(deviceSecretBytes) != 32 {
		writeError(w, http.StatusBadRequest, "invalid_device_secret")
		return
	}
	parsedInviteID, inviteTokenHash, err := auth.ParseToken(request.InviteToken)
	if err != nil || parsedInviteID != inviteID {
		writeError(w, http.StatusUnauthorized, "invalid_invite")
		return
	}
	deviceTokenHash := auth.HashSecret(request.DeviceSecret)
	device, err := s.store.ConsumeInvite(
		r.Context(), inviteID, inviteTokenHash, request.DeviceID, request.DeviceDisplayName, deviceTokenHash,
	)
	switch {
	case errors.Is(err, store.ErrNotFound):
		writeError(w, http.StatusNotFound, "invite_not_found")
		return
	case errors.Is(err, store.ErrUnauthorized):
		writeError(w, http.StatusUnauthorized, "invalid_invite")
		return
	case errors.Is(err, store.ErrInviteExpired):
		writeError(w, http.StatusGone, "invite_expired")
		return
	case errors.Is(err, store.ErrInviteConsumed):
		writeError(w, http.StatusGone, "invite_consumed")
		return
	case errors.Is(err, store.ErrInviteRevoked):
		writeError(w, http.StatusGone, "invite_revoked")
		return
	case errors.Is(err, store.ErrDeviceExists):
		writeError(w, http.StatusConflict, "device_exists")
		return
	case err != nil:
		s.internalError(w, err)
		return
	}
	writeJSON(w, http.StatusCreated, consumeInviteResponse{
		FamilySpaceID: device.FamilySpaceID,
		DeviceID:      device.ID,
		Role:          device.Role,
		DisplayName:   device.DisplayName,
		CreatedAt:     device.CreatedAt,
	})
}

type deviceResponse struct {
	DeviceID      string     `json:"deviceId"`
	FamilySpaceID string     `json:"familySpaceId"`
	DisplayName   string     `json:"displayName"`
	Role          string     `json:"role"`
	CreatedAt     time.Time  `json:"createdAt"`
	LastSeenAt    *time.Time `json:"lastSeenAt"`
	RevokedAt     *time.Time `json:"revokedAt"`
	IsCurrent     bool       `json:"isCurrent"`
}

func (s *Server) handleListDevices(w http.ResponseWriter, r *http.Request) {
	requester, err := s.authenticate(r)
	if !s.authorizeSpaceRequest(w, r, requester, err) {
		return
	}
	devices, err := s.store.ListDevices(r.Context(), requester.FamilySpaceID, requester.ID)
	if errors.Is(err, store.ErrForbidden) {
		writeError(w, http.StatusForbidden, "owner_required")
		return
	}
	if err != nil {
		s.internalError(w, err)
		return
	}
	items := make([]deviceResponse, 0, len(devices))
	for _, device := range devices {
		items = append(items, deviceResponse{
			DeviceID: device.ID, FamilySpaceID: device.FamilySpaceID,
			DisplayName: device.DisplayName, Role: device.Role,
			CreatedAt: device.CreatedAt, LastSeenAt: device.LastSeenAt,
			RevokedAt: device.RevokedAt, IsCurrent: device.ID == requester.ID,
		})
	}
	writeJSON(w, http.StatusOK, map[string]any{"devices": items})
}

func (s *Server) handleRevokeDevice(w http.ResponseWriter, r *http.Request) {
	requester, err := s.authenticate(r)
	if !s.authorizeSpaceRequest(w, r, requester, err) {
		return
	}
	targetDeviceID := r.PathValue("deviceId")
	if !uuidPattern.MatchString(targetDeviceID) {
		writeError(w, http.StatusNotFound, "device_not_found")
		return
	}
	revokedAt, err := s.store.RevokeDevice(r.Context(), requester.FamilySpaceID, requester.ID, targetDeviceID)
	switch {
	case errors.Is(err, store.ErrForbidden):
		writeError(w, http.StatusForbidden, "cannot_revoke_device")
	case errors.Is(err, store.ErrNotFound):
		writeError(w, http.StatusNotFound, "device_not_found")
	case err != nil:
		s.internalError(w, err)
	default:
		writeJSON(w, http.StatusOK, map[string]any{"deviceId": targetDeviceID, "revokedAt": revokedAt})
	}
}

func (s *Server) Handler() http.Handler { return s.handler }

func (s *Server) handleLive(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{"status": "live"})
}

func (s *Server) handleReady(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), time.Second)
	defer cancel()
	if err := s.store.Ready(ctx); err != nil {
		s.logger.Error("readiness check failed", "error", err)
		writeError(w, http.StatusServiceUnavailable, "not_ready")
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "ready"})
}

func (s *Server) handleBackupHealth(w http.ResponseWriter, _ *http.Request) {
	if s.backupStatusPath == "" {
		writeJSON(w, http.StatusOK, backupstatus.Unknown("backup_status_not_configured"))
		return
	}
	status, err := backupstatus.Read(s.backupStatusPath)
	if errors.Is(err, fs.ErrNotExist) {
		writeJSON(w, http.StatusOK, backupstatus.Unknown("backup_status_unavailable"))
		return
	}
	if err != nil {
		s.logger.Error("backup health status read failed", "error", err)
		writeJSON(w, http.StatusOK, backupstatus.Unknown("backup_status_invalid"))
		return
	}
	writeJSON(w, http.StatusOK, backupstatus.Evaluate(status, time.Now()))
}

type bootstrapSpaceRequest struct {
	DisplayName       string `json:"displayName"`
	FamilySpaceID     string `json:"familySpaceId"`
	DeviceID          string `json:"deviceId"`
	DeviceDisplayName string `json:"deviceDisplayName"`
	DeviceSecret      string `json:"deviceSecret"`
}

type bootstrapSpaceResponse struct {
	FamilySpaceID string `json:"familySpaceId"`
	DeviceID      string `json:"deviceId"`
	Role          string `json:"role"`
}

func (s *Server) handleBootstrapSpace(w http.ResponseWriter, r *http.Request) {
	provided, ok := bearerToken(r)
	providedHash := sha256.Sum256([]byte(provided))
	if !ok || subtle.ConstantTimeCompare(providedHash[:], s.bootstrapTokenHash[:]) != 1 {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	var request bootstrapSpaceRequest
	if err := decodeJSON(w, r, &request); err != nil {
		writeDecodeError(w, err)
		return
	}
	request.DisplayName = strings.TrimSpace(request.DisplayName)
	request.DeviceDisplayName = strings.TrimSpace(request.DeviceDisplayName)
	if request.DisplayName == "" || request.DeviceDisplayName == "" ||
		!uuidPattern.MatchString(request.FamilySpaceID) ||
		!uuidPattern.MatchString(request.DeviceID) ||
		len([]rune(request.DisplayName)) > 100 || len([]rune(request.DeviceDisplayName)) > 100 {
		writeError(w, http.StatusBadRequest, "invalid_request")
		return
	}
	deviceSecretBytes, err := base64.RawURLEncoding.DecodeString(request.DeviceSecret)
	if err != nil || len(deviceSecretBytes) != 32 {
		writeError(w, http.StatusBadRequest, "invalid_device_secret")
		return
	}
	tokenHash := auth.HashSecret(request.DeviceSecret)
	space, device, err := s.store.CreateSpace(
		r.Context(), request.DisplayName, request.FamilySpaceID,
		request.DeviceID, request.DeviceDisplayName, tokenHash,
	)
	if errors.Is(err, store.ErrSpaceExists) {
		writeError(w, http.StatusConflict, "space_exists")
		return
	}
	if errors.Is(err, store.ErrDeviceExists) {
		writeError(w, http.StatusConflict, "device_exists")
		return
	}
	if err != nil {
		s.internalError(w, err)
		return
	}
	writeJSON(w, http.StatusCreated, bootstrapSpaceResponse{
		FamilySpaceID: space.ID,
		DeviceID:      device.ID,
		Role:          device.Role,
	})
}

type exchangeRequest struct {
	ProtocolVersion int                      `json:"protocolVersion"`
	AfterCursor     *string                  `json:"afterCursor"`
	Limit           int                      `json:"limit"`
	Outgoing        []model.OutgoingEnvelope `json:"outgoing"`
}

type exchangeResponse struct {
	AcknowledgedChangeIDs []string                 `json:"acknowledgedChangeIds"`
	Incoming              []model.IncomingEnvelope `json:"incoming"`
	NextCursor            string                   `json:"nextCursor"`
	HasMore               bool                     `json:"hasMore"`
}

func (s *Server) handleExchange(w http.ResponseWriter, r *http.Request) {
	device, err := s.authenticate(r)
	if errors.Is(err, store.ErrUnauthorized) {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	if err != nil {
		s.internalError(w, err)
		return
	}
	spaceID := r.PathValue("spaceId")
	if !uuidPattern.MatchString(spaceID) || device.FamilySpaceID != spaceID {
		writeError(w, http.StatusForbidden, "space_forbidden")
		return
	}
	var request exchangeRequest
	if err := decodeJSON(w, r, &request); err != nil {
		writeDecodeError(w, err)
		return
	}
	if request.ProtocolVersion != protocolVersion {
		writeError(w, http.StatusBadRequest, "unsupported_protocol_version")
		return
	}
	after, err := parseCursor(request.AfterCursor)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid_cursor")
		return
	}
	if request.Limit == 0 {
		request.Limit = defaultLimit
	}
	if request.Limit < 1 || request.Limit > maxIncoming || len(request.Outgoing) > maxOutgoing {
		writeError(w, http.StatusBadRequest, "invalid_request")
		return
	}
	for _, envelope := range request.Outgoing {
		if err := validateEnvelope(envelope, device.ID); err != nil {
			writeError(w, http.StatusBadRequest, "invalid_envelope")
			return
		}
	}
	result, err := s.store.Exchange(r.Context(), spaceID, device.ID, after, request.Outgoing, request.Limit)
	if errors.Is(err, store.ErrChangeConflict) {
		writeError(w, http.StatusConflict, "change_id_conflict")
		return
	}
	if errors.Is(err, store.ErrUnauthorized) || errors.Is(err, store.ErrNotFound) {
		writeError(w, http.StatusForbidden, "space_forbidden")
		return
	}
	if err != nil {
		s.internalError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, exchangeResponse{
		AcknowledgedChangeIDs: result.AcknowledgedChangeIDs,
		Incoming:              result.Incoming,
		NextCursor:            strconv.FormatInt(result.NextCursor, 10),
		HasMore:               result.HasMore,
	})
}

func (s *Server) authenticate(r *http.Request) (model.Device, error) {
	token, ok := bearerToken(r)
	if !ok {
		return model.Device{}, store.ErrUnauthorized
	}
	deviceID, tokenHash, err := auth.ParseDeviceToken(token)
	if err != nil {
		return model.Device{}, store.ErrUnauthorized
	}
	return s.store.AuthenticateDevice(r.Context(), deviceID, tokenHash)
}

func (s *Server) authorizeSpaceRequest(w http.ResponseWriter, r *http.Request, device model.Device, err error) bool {
	if errors.Is(err, store.ErrUnauthorized) {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return false
	}
	if err != nil {
		s.internalError(w, err)
		return false
	}
	spaceID := r.PathValue("spaceId")
	if !uuidPattern.MatchString(spaceID) || device.FamilySpaceID != spaceID {
		writeError(w, http.StatusForbidden, "space_forbidden")
		return false
	}
	return true
}

func validateEnvelope(envelope model.OutgoingEnvelope, authenticatedDeviceID string) error {
	if envelope.EnvelopeVersion != 1 || !uuidPattern.MatchString(envelope.ChangeID) ||
		!uuidPattern.MatchString(envelope.SourceDeviceID) || envelope.SourceDeviceID != authenticatedDeviceID {
		return errors.New("invalid metadata")
	}
	nonce, err := base64.RawURLEncoding.DecodeString(envelope.Nonce)
	if err != nil || len(nonce) != 24 {
		return errors.New("invalid nonce")
	}
	ciphertext, err := base64.RawURLEncoding.DecodeString(envelope.Ciphertext)
	if err != nil || len(ciphertext) < 16 || len(ciphertext) > maxCiphertextBytes {
		return errors.New("invalid ciphertext")
	}
	return nil
}

func parseCursor(cursor *string) (int64, error) {
	if cursor == nil {
		return 0, nil
	}
	if *cursor == "" {
		return 0, errors.New("empty cursor")
	}
	value, err := strconv.ParseInt(*cursor, 10, 64)
	if err != nil || value < 0 {
		return 0, errors.New("invalid cursor")
	}
	return value, nil
}

func bearerToken(r *http.Request) (string, bool) {
	value := r.Header.Get("Authorization")
	const prefix = "Bearer "
	if !strings.HasPrefix(value, prefix) || len(value) == len(prefix) {
		return "", false
	}
	return value[len(prefix):], true
}

func decodeJSON(w http.ResponseWriter, r *http.Request, target any) error {
	r.Body = http.MaxBytesReader(w, r.Body, maxRequestBytes)
	decoder := json.NewDecoder(r.Body)
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(target); err != nil {
		return err
	}
	if err := decoder.Decode(&struct{}{}); !errors.Is(err, io.EOF) {
		if err == nil {
			return errors.New("multiple JSON values")
		}
		return err
	}
	return nil
}

func writeDecodeError(w http.ResponseWriter, err error) {
	var tooLarge *http.MaxBytesError
	if errors.As(err, &tooLarge) {
		writeError(w, http.StatusRequestEntityTooLarge, "request_too_large")
		return
	}
	writeError(w, http.StatusBadRequest, "invalid_json")
}

func (s *Server) internalError(w http.ResponseWriter, err error) {
	s.logger.Error("request failed", "error", err)
	writeError(w, http.StatusInternalServerError, "internal_error")
}

func writeError(w http.ResponseWriter, status int, code string) {
	writeJSONStatus(w, status, map[string]any{"error": map[string]string{"code": code}})
}

func writeJSON(w http.ResponseWriter, status int, value any) {
	writeJSONStatus(w, status, value)
}

func writeJSONStatus(w http.ResponseWriter, status int, value any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(value)
}

func (s *Server) recoverAndLog(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		started := time.Now()
		defer func() {
			if recovered := recover(); recovered != nil {
				s.logger.Error("handler panic", "panic", fmt.Sprint(recovered), "method", r.Method, "path", r.URL.Path)
				writeError(w, http.StatusInternalServerError, "internal_error")
			}
			s.logger.Info("request", "method", r.Method, "path", r.URL.Path, "duration", time.Since(started))
		}()
		next.ServeHTTP(w, r)
	})
}
