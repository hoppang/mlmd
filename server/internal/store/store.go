package store

import (
	"context"
	"errors"
	"time"

	"github.com/hoppang/mlmd/server/internal/model"
)

var (
	ErrNotFound       = errors.New("not found")
	ErrUnauthorized   = errors.New("unauthorized")
	ErrForbidden      = errors.New("forbidden")
	ErrChangeConflict = errors.New("change id already has different content")
	ErrInviteExpired  = errors.New("invite expired")
	ErrInviteConsumed = errors.New("invite already consumed")
	ErrInviteRevoked  = errors.New("invite revoked")
	ErrDeviceExists   = errors.New("device already exists")
	ErrSpaceExists    = errors.New("family space already exists")
)

type Store interface {
	Close() error
	Ready(context.Context) error
	CreateSpace(context.Context, string, string, string, string, []byte) (model.Space, model.Device, error)
	AuthenticateDevice(context.Context, string, []byte) (model.Device, error)
	CreateInvite(context.Context, string, string, string, []byte, time.Time) (model.Invite, error)
	ConsumeInvite(context.Context, string, []byte, string, string, []byte) (model.Device, error)
	ListDevices(context.Context, string, string) ([]model.Device, error)
	RevokeDevice(context.Context, string, string, string) (time.Time, error)
	Exchange(context.Context, string, string, int64, []model.OutgoingEnvelope, int) (model.ExchangeResult, error)
}
