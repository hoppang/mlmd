package model

import "time"

type Device struct {
	ID            string
	FamilySpaceID string
	Role          string
	DisplayName   string
	CreatedAt     time.Time
	LastSeenAt    *time.Time
	RevokedAt     *time.Time
}

type Space struct {
	ID          string
	DisplayName string
	CreatedAt   time.Time
}

type Invite struct {
	ID                string
	FamilySpaceID     string
	CreatedByDeviceID string
	Role              string
	CreatedAt         time.Time
	ExpiresAt         time.Time
	ConsumedAt        *time.Time
	RevokedAt         *time.Time
}

type OutgoingEnvelope struct {
	EnvelopeVersion int    `json:"envelopeVersion"`
	ChangeID        string `json:"changeId"`
	SourceDeviceID  string `json:"sourceDeviceId"`
	Nonce           string `json:"nonce"`
	Ciphertext      string `json:"ciphertext"`
}

type IncomingEnvelope struct {
	ServerSeq       int64     `json:"serverSeq"`
	ReceivedAt      time.Time `json:"receivedAt"`
	EnvelopeVersion int       `json:"envelopeVersion"`
	ChangeID        string    `json:"changeId"`
	SourceDeviceID  string    `json:"sourceDeviceId"`
	Nonce           string    `json:"nonce"`
	Ciphertext      string    `json:"ciphertext"`
}

type ExchangeResult struct {
	AcknowledgedChangeIDs []string
	Incoming              []IncomingEnvelope
	NextCursor            int64
	HasMore               bool
}
