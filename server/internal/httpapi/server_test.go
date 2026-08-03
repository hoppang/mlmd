package httpapi

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/hoppang/mlmd/server/internal/backupstatus"
	"github.com/hoppang/mlmd/server/internal/model"
	"github.com/hoppang/mlmd/server/internal/store/sqlite"
)

const bootstrapToken = "test-bootstrap-token-with-at-least-32-characters"

type testEnvironment struct {
	server           *httptest.Server
	store            *sqlite.Store
	spaceID          string
	deviceID         string
	deviceToken      string
	databasePath     string
	backupStatusPath string
}

func newTestEnvironment(t *testing.T) *testEnvironment {
	t.Helper()
	databasePath := filepath.Join(t.TempDir(), "mlmd-test.db")
	serverStore, err := sqlite.Open(t.Context(), databasePath)
	if err != nil {
		t.Fatal(err)
	}
	logger := slog.New(slog.NewTextHandler(io.Discard, nil))
	backupStatusPath := databasePath + ".backup-status.json"
	testServer := httptest.NewServer(New(serverStore, bootstrapToken, logger, backupStatusPath).Handler())
	environment := &testEnvironment{
		server: testServer, store: serverStore,
		databasePath: databasePath, backupStatusPath: backupStatusPath,
	}
	t.Cleanup(func() {
		testServer.Close()
		serverStore.Close()
	})
	environment.bootstrap(t)
	return environment
}

func (e *testEnvironment) bootstrap(t *testing.T) {
	t.Helper()
	deviceSecret := base64.RawURLEncoding.EncodeToString(bytes.Repeat([]byte{3}, 32))
	const deviceID = "11111111-2222-4333-8444-555555555555"
	response := e.request(t, http.MethodPost, "/v1/bootstrap/spaces", bootstrapToken, map[string]any{
		"displayName":       "Test family",
		"familySpaceId":     "550e8400-e29b-41d4-a716-446655440000",
		"deviceId":          deviceID,
		"deviceDisplayName": "Owner phone",
		"deviceSecret":      deviceSecret,
	})
	defer response.Body.Close()
	if response.StatusCode != http.StatusCreated {
		t.Fatalf("bootstrap status = %d, body = %s", response.StatusCode, readBody(t, response))
	}
	var payload struct {
		FamilySpaceID string `json:"familySpaceId"`
		DeviceID      string `json:"deviceId"`
	}
	decodeResponse(t, response, &payload)
	e.spaceID = payload.FamilySpaceID
	e.deviceID = payload.DeviceID
	e.deviceToken = payload.DeviceID + "." + deviceSecret
}

func (e *testEnvironment) request(t *testing.T, method, path, token string, body any) *http.Response {
	t.Helper()
	var encoded io.Reader
	if body != nil {
		data, err := json.Marshal(body)
		if err != nil {
			t.Fatal(err)
		}
		encoded = bytes.NewReader(data)
	}
	request, err := http.NewRequestWithContext(t.Context(), method, e.server.URL+path, encoded)
	if err != nil {
		t.Fatal(err)
	}
	if token != "" {
		request.Header.Set("Authorization", "Bearer "+token)
	}
	request.Header.Set("Content-Type", "application/json")
	response, err := http.DefaultClient.Do(request)
	if err != nil {
		t.Fatal(err)
	}
	return response
}

func TestHealthEndpoints(t *testing.T) {
	e := newTestEnvironment(t)
	for _, path := range []string{"/v1/health/live", "/v1/health/ready", "/v1/health/backup"} {
		response := e.request(t, http.MethodGet, path, "", nil)
		if response.StatusCode != http.StatusOK {
			t.Errorf("GET %s status = %d", path, response.StatusCode)
		}
		response.Body.Close()
	}
	response := e.request(t, http.MethodGet, "/v1/health/backup", "", nil)
	defer response.Body.Close()
	var status backupstatus.Status
	decodeResponse(t, response, &status)
	if status.State != backupstatus.StateUnknown {
		t.Fatalf("missing backup status should be unknown: %#v", status)
	}
}

func TestBackupHealthReportsSchedulerStatusWithoutChangingReadiness(t *testing.T) {
	e := newTestEnvironment(t)
	now := time.Now().UTC()
	next := now.Add(time.Hour)
	if err := backupstatus.RecordSuccess(e.backupStatusPath, backupstatus.Success{
		AttemptAt: now, BackupAt: now, BackupPath: "mlmd-auto-2026-08-03.mlmd-backup", NextAttemptAt: &next,
	}); err != nil {
		t.Fatal(err)
	}
	response := e.request(t, http.MethodGet, "/v1/health/backup", "", nil)
	defer response.Body.Close()
	var status backupstatus.Status
	decodeResponse(t, response, &status)
	if status.State != backupstatus.StateHealthy || status.LastBackupFile != "mlmd-auto-2026-08-03.mlmd-backup" {
		t.Fatalf("unexpected backup health: %#v", status)
	}
	if err := backupstatus.RecordFailure(e.backupStatusPath, now.Add(time.Minute), &next); err != nil {
		t.Fatal(err)
	}
	response = e.request(t, http.MethodGet, "/v1/health/backup", "", nil)
	var degraded backupstatus.Status
	decodeResponse(t, response, &degraded)
	response.Body.Close()
	if degraded.State != backupstatus.StateDegraded || degraded.ErrorCode != "backup_cycle_failed" {
		t.Fatalf("backup failure was not reported: %#v", degraded)
	}
	response = e.request(t, http.MethodGet, "/v1/health/ready", "", nil)
	defer response.Body.Close()
	if response.StatusCode != http.StatusOK {
		t.Fatalf("backup degradation changed readiness: %d", response.StatusCode)
	}
}

func TestBootstrapRetryReturnsExistingSpace(t *testing.T) {
	e := newTestEnvironment(t)
	deviceSecret := base64.RawURLEncoding.EncodeToString(bytes.Repeat([]byte{3}, 32))
	response := e.request(t, http.MethodPost, "/v1/bootstrap/spaces", bootstrapToken, map[string]any{
		"displayName":       "Test family",
		"familySpaceId":     e.spaceID,
		"deviceId":          e.deviceID,
		"deviceDisplayName": "Owner phone",
		"deviceSecret":      deviceSecret,
	})
	defer response.Body.Close()
	if response.StatusCode != http.StatusCreated {
		t.Fatalf("bootstrap retry status = %d, body = %s", response.StatusCode, readBody(t, response))
	}
	var payload struct {
		FamilySpaceID string `json:"familySpaceId"`
		DeviceID      string `json:"deviceId"`
	}
	decodeResponse(t, response, &payload)
	if payload.FamilySpaceID != e.spaceID || payload.DeviceID != e.deviceID {
		t.Fatalf("unexpected bootstrap retry response: %#v", payload)
	}
}

func TestGoldenExchangeRequestMatchesServerContract(t *testing.T) {
	fixturePath := filepath.Join("..", "..", "..", "protocol", "fixtures", "exchange-v1-request.golden.json")
	data, err := os.ReadFile(fixturePath)
	if err != nil {
		t.Fatal(err)
	}
	var request struct {
		ProtocolVersion int                      `json:"protocolVersion"`
		AfterCursor     *string                  `json:"afterCursor"`
		Limit           int                      `json:"limit"`
		Outgoing        []model.OutgoingEnvelope `json:"outgoing"`
	}
	if err := json.Unmarshal(data, &request); err != nil {
		t.Fatal(err)
	}
	if request.ProtocolVersion != 1 || request.AfterCursor == nil || request.Limit != 200 || len(request.Outgoing) != 1 {
		t.Fatalf("unexpected golden request: %#v", request)
	}
	if err := validateEnvelope(request.Outgoing[0], request.Outgoing[0].SourceDeviceID); err != nil {
		t.Fatal(err)
	}
}

func TestExchangeIsIdempotentAndCursorBased(t *testing.T) {
	e := newTestEnvironment(t)
	envelope := validEnvelope(e.deviceID, "550e8400-e29b-41d4-a716-446655440000")

	first := e.exchange(t, nil, 200, []model.OutgoingEnvelope{envelope})
	if len(first.AcknowledgedChangeIDs) != 1 || first.AcknowledgedChangeIDs[0] != envelope.ChangeID {
		t.Fatalf("unexpected ack: %#v", first.AcknowledgedChangeIDs)
	}
	if len(first.Incoming) != 1 || first.Incoming[0].ServerSeq != 1 || first.NextCursor != "1" {
		t.Fatalf("unexpected first exchange: %#v", first)
	}

	repeated := e.exchange(t, nil, 200, []model.OutgoingEnvelope{envelope})
	if len(repeated.AcknowledgedChangeIDs) != 1 || len(repeated.Incoming) != 1 || repeated.Incoming[0].ServerSeq != 1 {
		t.Fatalf("duplicate submission was not idempotent: %#v", repeated)
	}

	cursor := "1"
	after := e.exchange(t, &cursor, 200, nil)
	if len(after.Incoming) != 0 || after.NextCursor != "1" || after.HasMore {
		t.Fatalf("unexpected cursor response: %#v", after)
	}
}

func TestExchangePaginatesInServerSequenceOrder(t *testing.T) {
	e := newTestEnvironment(t)
	firstChange := validEnvelope(e.deviceID, "550e8400-e29b-41d4-a716-446655440001")
	secondChange := validEnvelope(e.deviceID, "550e8400-e29b-41d4-a716-446655440002")
	firstPage := e.exchange(t, nil, 1, []model.OutgoingEnvelope{firstChange, secondChange})
	if len(firstPage.Incoming) != 1 || firstPage.Incoming[0].ServerSeq != 1 || !firstPage.HasMore {
		t.Fatalf("unexpected first page: %#v", firstPage)
	}
	cursor := firstPage.NextCursor
	secondPage := e.exchange(t, &cursor, 1, nil)
	if len(secondPage.Incoming) != 1 || secondPage.Incoming[0].ServerSeq != 2 || secondPage.HasMore {
		t.Fatalf("unexpected second page: %#v", secondPage)
	}
}

func TestExchangeRejectsDifferentContentForSameChangeID(t *testing.T) {
	e := newTestEnvironment(t)
	envelope := validEnvelope(e.deviceID, "550e8400-e29b-41d4-a716-446655440003")
	e.exchange(t, nil, 200, []model.OutgoingEnvelope{envelope})
	envelope.Ciphertext = base64.RawURLEncoding.EncodeToString(bytes.Repeat([]byte{1}, 16))
	response := e.request(t, http.MethodPost, "/v1/spaces/"+e.spaceID+"/exchange", e.deviceToken, map[string]any{
		"protocolVersion": 1, "afterCursor": nil, "limit": 200, "outgoing": []model.OutgoingEnvelope{envelope},
	})
	defer response.Body.Close()
	if response.StatusCode != http.StatusConflict {
		t.Fatalf("status = %d, body = %s", response.StatusCode, readBody(t, response))
	}
}

func TestExchangeRequiresMatchingAuthenticatedDevice(t *testing.T) {
	e := newTestEnvironment(t)
	envelope := validEnvelope("aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee", "550e8400-e29b-41d4-a716-446655440004")
	response := e.request(t, http.MethodPost, "/v1/spaces/"+e.spaceID+"/exchange", e.deviceToken, map[string]any{
		"protocolVersion": 1, "afterCursor": nil, "limit": 200, "outgoing": []model.OutgoingEnvelope{envelope},
	})
	defer response.Body.Close()
	if response.StatusCode != http.StatusBadRequest {
		t.Fatalf("status = %d, body = %s", response.StatusCode, readBody(t, response))
	}
}

func TestOwnerCanInviteListAndRevokeDevice(t *testing.T) {
	e := newTestEnvironment(t)
	createResponse := e.request(t, http.MethodPost, "/v1/spaces/"+e.spaceID+"/invites", e.deviceToken, map[string]any{
		"role": "member",
	})
	if createResponse.StatusCode != http.StatusCreated {
		t.Fatalf("create invite status = %d, body = %s", createResponse.StatusCode, readBody(t, createResponse))
	}
	var invite struct {
		InviteID    string `json:"inviteId"`
		InviteToken string `json:"inviteToken"`
		Role        string `json:"role"`
	}
	decodeResponse(t, createResponse, &invite)
	createResponse.Body.Close()

	const invitedDeviceID = "66666666-7777-4888-8999-aaaaaaaaaaaa"
	deviceSecret := base64.RawURLEncoding.EncodeToString(bytes.Repeat([]byte{7}, 32))
	consumeBody := map[string]any{
		"inviteToken":       invite.InviteToken,
		"deviceId":          invitedDeviceID,
		"deviceDisplayName": "Grandparent tablet",
		"deviceSecret":      deviceSecret,
	}
	consumeResponse := e.request(t, http.MethodPost, "/v1/invites/"+invite.InviteID+"/consume", "", consumeBody)
	if consumeResponse.StatusCode != http.StatusCreated {
		t.Fatalf("consume invite status = %d, body = %s", consumeResponse.StatusCode, readBody(t, consumeResponse))
	}
	var consumed struct {
		FamilySpaceID string `json:"familySpaceId"`
		DeviceID      string `json:"deviceId"`
		Role          string `json:"role"`
	}
	decodeResponse(t, consumeResponse, &consumed)
	consumeResponse.Body.Close()
	if consumed.FamilySpaceID != e.spaceID || consumed.DeviceID != invitedDeviceID || consumed.Role != "member" {
		t.Fatalf("unexpected consume response: %#v", consumed)
	}

	replayResponse := e.request(t, http.MethodPost, "/v1/invites/"+invite.InviteID+"/consume", "", consumeBody)
	if replayResponse.StatusCode != http.StatusCreated {
		t.Fatalf("invite replay status = %d, body = %s", replayResponse.StatusCode, readBody(t, replayResponse))
	}
	replayResponse.Body.Close()

	otherDeviceBody := map[string]any{
		"inviteToken":       invite.InviteToken,
		"deviceId":          "77777777-8888-4999-8aaa-bbbbbbbbbbbb",
		"deviceDisplayName": "Other tablet",
		"deviceSecret":      base64.RawURLEncoding.EncodeToString(bytes.Repeat([]byte{8}, 32)),
	}
	otherDeviceResponse := e.request(t, http.MethodPost, "/v1/invites/"+invite.InviteID+"/consume", "", otherDeviceBody)
	if otherDeviceResponse.StatusCode != http.StatusGone {
		t.Fatalf("other device replay status = %d, body = %s", otherDeviceResponse.StatusCode, readBody(t, otherDeviceResponse))
	}
	otherDeviceResponse.Body.Close()

	listResponse := e.request(t, http.MethodGet, "/v1/spaces/"+e.spaceID+"/devices", e.deviceToken, nil)
	if listResponse.StatusCode != http.StatusOK {
		t.Fatalf("list devices status = %d, body = %s", listResponse.StatusCode, readBody(t, listResponse))
	}
	var listed struct {
		Devices []struct {
			DeviceID  string `json:"deviceId"`
			IsCurrent bool   `json:"isCurrent"`
		} `json:"devices"`
	}
	decodeResponse(t, listResponse, &listed)
	listResponse.Body.Close()
	if len(listed.Devices) != 2 || !listed.Devices[0].IsCurrent || listed.Devices[1].IsCurrent {
		t.Fatalf("unexpected device list: %#v", listed.Devices)
	}

	invitedToken := invitedDeviceID + "." + deviceSecret
	memberListResponse := e.request(t, http.MethodGet, "/v1/spaces/"+e.spaceID+"/devices", invitedToken, nil)
	if memberListResponse.StatusCode != http.StatusForbidden {
		t.Fatalf("member list status = %d, body = %s", memberListResponse.StatusCode, readBody(t, memberListResponse))
	}
	memberListResponse.Body.Close()

	revokeResponse := e.request(t, http.MethodDelete, "/v1/spaces/"+e.spaceID+"/devices/"+invitedDeviceID, e.deviceToken, nil)
	if revokeResponse.StatusCode != http.StatusOK {
		t.Fatalf("revoke status = %d, body = %s", revokeResponse.StatusCode, readBody(t, revokeResponse))
	}
	var firstRevocation struct {
		RevokedAt time.Time `json:"revokedAt"`
	}
	decodeResponse(t, revokeResponse, &firstRevocation)

	retryRevokeResponse := e.request(t, http.MethodDelete, "/v1/spaces/"+e.spaceID+"/devices/"+invitedDeviceID, e.deviceToken, nil)
	if retryRevokeResponse.StatusCode != http.StatusOK {
		t.Fatalf("retry revoke status = %d, body = %s", retryRevokeResponse.StatusCode, readBody(t, retryRevokeResponse))
	}
	var retriedRevocation struct {
		RevokedAt time.Time `json:"revokedAt"`
	}
	decodeResponse(t, retryRevokeResponse, &retriedRevocation)
	if !retriedRevocation.RevokedAt.Equal(firstRevocation.RevokedAt) {
		t.Fatalf("retry revoke timestamp = %s, want %s", retriedRevocation.RevokedAt, firstRevocation.RevokedAt)
	}

	revokedExchange := e.request(t, http.MethodPost, "/v1/spaces/"+e.spaceID+"/exchange", invitedToken, map[string]any{
		"protocolVersion": 1, "afterCursor": nil, "limit": 200, "outgoing": []model.OutgoingEnvelope{},
	})
	if revokedExchange.StatusCode != http.StatusUnauthorized {
		t.Fatalf("revoked token status = %d, body = %s", revokedExchange.StatusCode, readBody(t, revokedExchange))
	}
	revokedExchange.Body.Close()
}

func TestOwnerCannotRevokeCurrentDevice(t *testing.T) {
	e := newTestEnvironment(t)
	response := e.request(t, http.MethodDelete, "/v1/spaces/"+e.spaceID+"/devices/"+e.deviceID, e.deviceToken, nil)
	defer response.Body.Close()
	if response.StatusCode != http.StatusForbidden {
		t.Fatalf("status = %d, body = %s", response.StatusCode, readBody(t, response))
	}
}

func (e *testEnvironment) exchange(t *testing.T, cursor *string, limit int, outgoing []model.OutgoingEnvelope) exchangePayload {
	t.Helper()
	response := e.request(t, http.MethodPost, "/v1/spaces/"+e.spaceID+"/exchange", e.deviceToken, map[string]any{
		"protocolVersion": 1,
		"afterCursor":     cursor,
		"limit":           limit,
		"outgoing":        outgoing,
	})
	defer response.Body.Close()
	if response.StatusCode != http.StatusOK {
		t.Fatalf("exchange status = %d, body = %s", response.StatusCode, readBody(t, response))
	}
	var payload exchangePayload
	decodeResponse(t, response, &payload)
	return payload
}

type exchangePayload struct {
	AcknowledgedChangeIDs []string                 `json:"acknowledgedChangeIds"`
	Incoming              []model.IncomingEnvelope `json:"incoming"`
	NextCursor            string                   `json:"nextCursor"`
	HasMore               bool                     `json:"hasMore"`
}

func validEnvelope(deviceID, changeID string) model.OutgoingEnvelope {
	return model.OutgoingEnvelope{
		EnvelopeVersion: 1,
		ChangeID:        changeID,
		SourceDeviceID:  deviceID,
		Nonce:           base64.RawURLEncoding.EncodeToString(make([]byte, 24)),
		Ciphertext:      base64.RawURLEncoding.EncodeToString(make([]byte, 16)),
	}
}

func decodeResponse(t *testing.T, response *http.Response, target any) {
	t.Helper()
	if err := json.NewDecoder(response.Body).Decode(target); err != nil {
		t.Fatal(err)
	}
}

func readBody(t *testing.T, response *http.Response) string {
	t.Helper()
	data, err := io.ReadAll(response.Body)
	if err != nil {
		t.Fatal(err)
	}
	return string(data)
}
