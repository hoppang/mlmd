package sqlite_test

import (
	"context"
	"database/sql"
	"encoding/base64"
	"errors"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/hoppang/mlmd/server/internal/auth"
	"github.com/hoppang/mlmd/server/internal/model"
	storepkg "github.com/hoppang/mlmd/server/internal/store"
	"github.com/hoppang/mlmd/server/internal/store/sqlite"
)

func TestStateSurvivesStoreRestart(t *testing.T) {
	ctx := context.Background()
	databasePath := filepath.Join(t.TempDir(), "restart.db")
	secret, tokenHash, err := auth.NewSecret()
	if err != nil {
		t.Fatal(err)
	}

	firstStore, err := sqlite.Open(ctx, databasePath)
	if err != nil {
		t.Fatal(err)
	}
	space, device, err := firstStore.CreateSpace(
		ctx,
		"Family",
		"550e8400-e29b-41d4-a716-446655440000",
		"11111111-2222-4333-8444-555555555555",
		"Phone",
		tokenHash,
	)
	if err != nil {
		t.Fatal(err)
	}
	envelope := model.OutgoingEnvelope{
		EnvelopeVersion: 1,
		ChangeID:        "550e8400-e29b-41d4-a716-446655440010",
		SourceDeviceID:  device.ID,
		Nonce:           base64.RawURLEncoding.EncodeToString(make([]byte, 24)),
		Ciphertext:      base64.RawURLEncoding.EncodeToString(make([]byte, 16)),
	}
	if _, err := firstStore.Exchange(ctx, space.ID, device.ID, 0, []model.OutgoingEnvelope{envelope}, 200); err != nil {
		t.Fatal(err)
	}
	if err := firstStore.Close(); err != nil {
		t.Fatal(err)
	}

	reopened, err := sqlite.Open(ctx, databasePath)
	if err != nil {
		t.Fatal(err)
	}
	defer reopened.Close()
	parsedDeviceID, parsedHash, err := auth.ParseDeviceToken(device.ID + "." + secret)
	if err != nil {
		t.Fatal(err)
	}
	authenticated, err := reopened.AuthenticateDevice(ctx, parsedDeviceID, parsedHash)
	if err != nil || authenticated.ID != device.ID {
		t.Fatalf("device authentication after restart failed: device=%#v err=%v", authenticated, err)
	}
	result, err := reopened.Exchange(ctx, space.ID, device.ID, 0, []model.OutgoingEnvelope{envelope}, 200)
	if err != nil {
		t.Fatal(err)
	}
	if len(result.AcknowledgedChangeIDs) != 1 || len(result.Incoming) != 1 || result.Incoming[0].ServerSeq != 1 {
		t.Fatalf("state was not restored idempotently: %#v", result)
	}
	_, secondTokenHash, err := auth.NewSecret()
	if err != nil {
		t.Fatal(err)
	}
	_, _, err = reopened.CreateSpace(
		ctx,
		"Another family",
		"650e8400-e29b-41d4-a716-446655440000",
		"21111111-2222-4333-8444-555555555555",
		"Another phone",
		secondTokenHash,
	)
	if !errors.Is(err, storepkg.ErrBootstrapConsumed) {
		t.Fatalf("bootstrap consumption did not survive restart: %v", err)
	}
}

func TestExchangeRetainsHistoryAfterDeviceCursorAdvances(t *testing.T) {
	ctx := context.Background()
	store, err := sqlite.Open(ctx, filepath.Join(t.TempDir(), "retention.db"))
	if err != nil {
		t.Fatal(err)
	}
	defer store.Close()
	_, tokenHash, err := auth.NewSecret()
	if err != nil {
		t.Fatal(err)
	}
	space, device, err := store.CreateSpace(
		ctx,
		"Family",
		"550e8400-e29b-41d4-a716-446655440030",
		"11111111-2222-4333-8444-555555555557",
		"Phone",
		tokenHash,
	)
	if err != nil {
		t.Fatal(err)
	}
	envelope := model.OutgoingEnvelope{
		EnvelopeVersion: 1,
		ChangeID:        "550e8400-e29b-41d4-a716-446655440031",
		SourceDeviceID:  device.ID,
		Nonce:           base64.RawURLEncoding.EncodeToString(make([]byte, 24)),
		Ciphertext:      base64.RawURLEncoding.EncodeToString(make([]byte, 16)),
	}

	first, err := store.Exchange(ctx, space.ID, device.ID, 0, []model.OutgoingEnvelope{envelope}, 200)
	if err != nil {
		t.Fatal(err)
	}
	if len(first.Incoming) != 1 || first.NextCursor != 1 {
		t.Fatalf("unexpected initial exchange: %#v", first)
	}
	if _, err := store.Exchange(ctx, space.ID, device.ID, first.NextCursor, nil, 200); err != nil {
		t.Fatal(err)
	}

	replayed, err := store.Exchange(ctx, space.ID, device.ID, 0, nil, 200)
	if err != nil {
		t.Fatal(err)
	}
	if len(replayed.Incoming) != 1 || replayed.Incoming[0].ChangeID != envelope.ChangeID {
		t.Fatalf("cursor advancement pruned retained history: %#v", replayed.Incoming)
	}
}

func TestSnapshotCompactsChangesAfterAllActiveDevicesReportBase(t *testing.T) {
	ctx := context.Background()
	testStore, space, owner := newSyncStore(t, ctx, "compact-all.db")
	member := addMember(t, ctx, testStore, space.ID, owner.ID, "22222222-2222-4333-8444-555555555551")
	envelope := testEnvelope(owner.ID, "550e8400-e29b-41d4-a716-446655440041")

	ownerResult, err := testStore.Exchange(ctx, space.ID, owner.ID, 0, []model.OutgoingEnvelope{envelope}, 200)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := testStore.Exchange(ctx, space.ID, owner.ID, ownerResult.NextCursor, nil, 200); err != nil {
		t.Fatal(err)
	}
	snapshot := testSnapshot(owner.ID, ownerResult.NextCursor, "550e8400-e29b-41d4-a716-446655440042")
	if _, err := testStore.PutSnapshot(ctx, space.ID, owner.ID, snapshot); err != nil {
		t.Fatal(err)
	}

	stillRetained, err := testStore.Exchange(ctx, space.ID, owner.ID, 0, nil, 200)
	if err != nil {
		t.Fatal(err)
	}
	if len(stillRetained.Incoming) != 1 {
		t.Fatalf("active device without a cursor did not block compaction: %#v", stillRetained.Incoming)
	}

	memberResult, err := testStore.Exchange(ctx, space.ID, member.ID, 0, nil, 200)
	if err != nil {
		t.Fatal(err)
	}
	if len(memberResult.Incoming) != 1 || memberResult.NextCursor != snapshot.BaseServerSeq {
		t.Fatalf("member did not receive retained history: %#v", memberResult)
	}
	if _, err := testStore.Exchange(ctx, space.ID, member.ID, memberResult.NextCursor, nil, 200); err != nil {
		t.Fatal(err)
	}

	compacted, err := testStore.Exchange(ctx, space.ID, owner.ID, 0, nil, 200)
	if err != nil {
		t.Fatal(err)
	}
	if len(compacted.Incoming) != 0 {
		t.Fatalf("history at the snapshot base was not compacted: %#v", compacted.Incoming)
	}
	retried, err := testStore.Exchange(ctx, space.ID, owner.ID, 0, []model.OutgoingEnvelope{envelope}, 200)
	if err != nil {
		t.Fatal(err)
	}
	if len(retried.AcknowledgedChangeIDs) != 1 || len(retried.Incoming) != 0 {
		t.Fatalf("compacted change retry was not idempotent: %#v", retried)
	}
	conflictingEnvelope := envelope
	conflictingEnvelope.Ciphertext = base64.RawURLEncoding.EncodeToString([]byte("different content"))
	if _, err := testStore.Exchange(ctx, space.ID, owner.ID, 0, []model.OutgoingEnvelope{conflictingEnvelope}, 200); !errors.Is(err, storepkg.ErrChangeConflict) {
		t.Fatalf("compacted change lost conflict detection: %v", err)
	}
	stored, err := testStore.GetSnapshot(ctx, space.ID)
	if err != nil || stored.SnapshotID != snapshot.SnapshotID {
		t.Fatalf("snapshot was not retained after compaction: snapshot=%#v err=%v", stored, err)
	}
}

func TestSnapshotCompactionKeepsChangesAboveBase(t *testing.T) {
	ctx := context.Background()
	testStore, space, owner := newSyncStore(t, ctx, "compact-boundary.db")
	firstEnvelope := testEnvelope(owner.ID, "550e8400-e29b-41d4-a716-446655440051")
	secondEnvelope := testEnvelope(owner.ID, "550e8400-e29b-41d4-a716-446655440052")

	result, err := testStore.Exchange(ctx, space.ID, owner.ID, 0, []model.OutgoingEnvelope{firstEnvelope, secondEnvelope}, 200)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := testStore.Exchange(ctx, space.ID, owner.ID, result.NextCursor, nil, 200); err != nil {
		t.Fatal(err)
	}
	if _, err := testStore.PutSnapshot(ctx, space.ID, owner.ID, testSnapshot(owner.ID, 1, "550e8400-e29b-41d4-a716-446655440053")); err != nil {
		t.Fatal(err)
	}

	replayed, err := testStore.Exchange(ctx, space.ID, owner.ID, 0, nil, 200)
	if err != nil {
		t.Fatal(err)
	}
	if len(replayed.Incoming) != 1 || replayed.Incoming[0].ServerSeq != 2 || replayed.Incoming[0].ChangeID != secondEnvelope.ChangeID {
		t.Fatalf("compaction crossed the snapshot boundary: %#v", replayed.Incoming)
	}
}

func TestNewerSnapshotAdvancesCompactionBoundary(t *testing.T) {
	ctx := context.Background()
	testStore, space, owner := newSyncStore(t, ctx, "compact-replacement.db")
	firstEnvelope := testEnvelope(owner.ID, "550e8400-e29b-41d4-a716-446655440071")
	firstResult, err := testStore.Exchange(ctx, space.ID, owner.ID, 0, []model.OutgoingEnvelope{firstEnvelope}, 200)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := testStore.Exchange(ctx, space.ID, owner.ID, firstResult.NextCursor, nil, 200); err != nil {
		t.Fatal(err)
	}
	if _, err := testStore.PutSnapshot(ctx, space.ID, owner.ID, testSnapshot(owner.ID, 1, "550e8400-e29b-41d4-a716-446655440072")); err != nil {
		t.Fatal(err)
	}

	secondEnvelope := testEnvelope(owner.ID, "550e8400-e29b-41d4-a716-446655440073")
	secondResult, err := testStore.Exchange(ctx, space.ID, owner.ID, 1, []model.OutgoingEnvelope{secondEnvelope}, 200)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := testStore.Exchange(ctx, space.ID, owner.ID, secondResult.NextCursor, nil, 200); err != nil {
		t.Fatal(err)
	}
	newerSnapshot := testSnapshot(owner.ID, 2, "550e8400-e29b-41d4-a716-446655440074")
	if _, err := testStore.PutSnapshot(ctx, space.ID, owner.ID, newerSnapshot); err != nil {
		t.Fatal(err)
	}

	replayed, err := testStore.Exchange(ctx, space.ID, owner.ID, 0, nil, 200)
	if err != nil {
		t.Fatal(err)
	}
	if len(replayed.Incoming) != 0 {
		t.Fatalf("newer snapshot did not advance compaction boundary: %#v", replayed.Incoming)
	}
	stored, err := testStore.GetSnapshot(ctx, space.ID)
	if err != nil || stored.SnapshotID != newerSnapshot.SnapshotID || stored.BaseServerSeq != 2 {
		t.Fatalf("newer snapshot was not retained: snapshot=%#v err=%v", stored, err)
	}
}

func TestRevokedLaggingDeviceDoesNotBlockSnapshotCompaction(t *testing.T) {
	ctx := context.Background()
	testStore, space, owner := newSyncStore(t, ctx, "compact-revoked.db")
	member := addMember(t, ctx, testStore, space.ID, owner.ID, "22222222-2222-4333-8444-555555555552")
	envelope := testEnvelope(owner.ID, "550e8400-e29b-41d4-a716-446655440061")

	result, err := testStore.Exchange(ctx, space.ID, owner.ID, 0, []model.OutgoingEnvelope{envelope}, 200)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := testStore.Exchange(ctx, space.ID, owner.ID, result.NextCursor, nil, 200); err != nil {
		t.Fatal(err)
	}
	if _, err := testStore.PutSnapshot(ctx, space.ID, owner.ID, testSnapshot(owner.ID, result.NextCursor, "550e8400-e29b-41d4-a716-446655440062")); err != nil {
		t.Fatal(err)
	}
	if _, err := testStore.RevokeDevice(ctx, space.ID, owner.ID, member.ID); err != nil {
		t.Fatal(err)
	}

	replayed, err := testStore.Exchange(ctx, space.ID, owner.ID, 0, nil, 200)
	if err != nil {
		t.Fatal(err)
	}
	if len(replayed.Incoming) != 0 {
		t.Fatalf("revoked lagging device still blocked compaction: %#v", replayed.Incoming)
	}
}

func newSyncStore(t *testing.T, ctx context.Context, databaseName string) (*sqlite.Store, model.Space, model.Device) {
	t.Helper()
	testStore, err := sqlite.Open(ctx, filepath.Join(t.TempDir(), databaseName))
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { testStore.Close() })
	_, tokenHash, err := auth.NewSecret()
	if err != nil {
		t.Fatal(err)
	}
	space, owner, err := testStore.CreateSpace(
		ctx,
		"Family",
		"550e8400-e29b-41d4-a716-446655440040",
		"11111111-2222-4333-8444-555555555558",
		"Owner phone",
		tokenHash,
	)
	if err != nil {
		t.Fatal(err)
	}
	return testStore, space, owner
}

func addMember(t *testing.T, ctx context.Context, testStore *sqlite.Store, spaceID, ownerID, memberID string) model.Device {
	t.Helper()
	_, inviteTokenHash, err := auth.NewSecret()
	if err != nil {
		t.Fatal(err)
	}
	invite, err := testStore.CreateInvite(ctx, spaceID, ownerID, "member", inviteTokenHash, time.Now().Add(time.Hour))
	if err != nil {
		t.Fatal(err)
	}
	_, memberTokenHash, err := auth.NewSecret()
	if err != nil {
		t.Fatal(err)
	}
	member, err := testStore.ConsumeInvite(ctx, invite.ID, inviteTokenHash, memberID, "Member phone", memberTokenHash)
	if err != nil {
		t.Fatal(err)
	}
	return member
}

func testEnvelope(deviceID, changeID string) model.OutgoingEnvelope {
	return model.OutgoingEnvelope{
		EnvelopeVersion: 1,
		ChangeID:        changeID,
		SourceDeviceID:  deviceID,
		Nonce:           base64.RawURLEncoding.EncodeToString(make([]byte, 24)),
		Ciphertext:      base64.RawURLEncoding.EncodeToString(make([]byte, 16)),
	}
}

func testSnapshot(deviceID string, baseServerSeq int64, snapshotID string) model.SyncSnapshot {
	return model.SyncSnapshot{
		SnapshotID:      snapshotID,
		BaseServerSeq:   baseServerSeq,
		SourceDeviceID:  deviceID,
		SnapshotVersion: 1,
		Nonce:           base64.RawURLEncoding.EncodeToString(make([]byte, 24)),
		Ciphertext:      base64.RawURLEncoding.EncodeToString(make([]byte, 16)),
	}
}

func TestBackupCapturesLiveWALSnapshot(t *testing.T) {
	ctx := context.Background()
	tempDir := t.TempDir()
	databasePath := filepath.Join(tempDir, "live.db")
	backupPath := filepath.Join(tempDir, "backups", "snapshot.db")
	_, tokenHash, err := auth.NewSecret()
	if err != nil {
		t.Fatal(err)
	}

	liveStore, err := sqlite.Open(ctx, databasePath)
	if err != nil {
		t.Fatal(err)
	}
	defer liveStore.Close()
	space, device, err := liveStore.CreateSpace(
		ctx,
		"Family",
		"550e8400-e29b-41d4-a716-446655440020",
		"11111111-2222-4333-8444-555555555556",
		"Phone",
		tokenHash,
	)
	if err != nil {
		t.Fatal(err)
	}
	firstEnvelope := model.OutgoingEnvelope{
		EnvelopeVersion: 1,
		ChangeID:        "550e8400-e29b-41d4-a716-446655440021",
		SourceDeviceID:  device.ID,
		Nonce:           base64.RawURLEncoding.EncodeToString(make([]byte, 24)),
		Ciphertext:      base64.RawURLEncoding.EncodeToString(make([]byte, 16)),
	}
	if _, err := liveStore.Exchange(ctx, space.ID, device.ID, 0, []model.OutgoingEnvelope{firstEnvelope}, 200); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(databasePath + "-wal"); err != nil {
		t.Fatalf("expected live WAL file: %v", err)
	}

	backupSource, err := sqlite.Open(ctx, databasePath)
	if err != nil {
		t.Fatal(err)
	}
	if err := backupSource.Backup(ctx, backupPath); err != nil {
		backupSource.Close()
		t.Fatal(err)
	}
	if err := backupSource.Close(); err != nil {
		t.Fatal(err)
	}
	secondEnvelope := firstEnvelope
	secondEnvelope.ChangeID = "550e8400-e29b-41d4-a716-446655440022"
	if _, err := liveStore.Exchange(ctx, space.ID, device.ID, 0, []model.OutgoingEnvelope{secondEnvelope}, 200); err != nil {
		t.Fatal(err)
	}

	backupStore, err := sqlite.Open(ctx, backupPath)
	if err != nil {
		t.Fatal(err)
	}
	defer backupStore.Close()
	if _, err := backupStore.AuthenticateDevice(ctx, device.ID, tokenHash); err != nil {
		t.Fatalf("backup did not preserve device authentication: %v", err)
	}
	result, err := backupStore.Exchange(ctx, space.ID, device.ID, 0, nil, 200)
	if err != nil {
		t.Fatal(err)
	}
	if len(result.Incoming) != 1 || result.Incoming[0].ChangeID != firstEnvelope.ChangeID {
		t.Fatalf("backup is not the expected point-in-time snapshot: %#v", result.Incoming)
	}
}

func TestBackupRefusesToOverwriteDestination(t *testing.T) {
	ctx := context.Background()
	tempDir := t.TempDir()
	store, err := sqlite.Open(ctx, filepath.Join(tempDir, "source.db"))
	if err != nil {
		t.Fatal(err)
	}
	defer store.Close()

	destination := filepath.Join(tempDir, "existing.db")
	if err := os.WriteFile(destination, []byte("keep me"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := store.Backup(ctx, destination); !errors.Is(err, sqlite.ErrBackupDestinationExists) {
		t.Fatalf("expected destination-exists error, got %v", err)
	}
	contents, err := os.ReadFile(destination)
	if err != nil {
		t.Fatal(err)
	}
	if string(contents) != "keep me" {
		t.Fatalf("existing destination was modified: %q", contents)
	}
}

func TestPrepareRestoreMigratesVersionTwoWithoutSnapshotTable(t *testing.T) {
	ctx := context.Background()
	databasePath := filepath.Join(t.TempDir(), "version-two.db")
	store, err := sqlite.Open(ctx, databasePath)
	if err != nil {
		t.Fatal(err)
	}
	if err := store.Close(); err != nil {
		t.Fatal(err)
	}
	db, err := sql.Open("sqlite", "file:"+filepath.ToSlash(databasePath))
	if err != nil {
		t.Fatal(err)
	}
	if _, err := db.Exec(`DROP TABLE sync_snapshots; PRAGMA user_version = 2;`); err != nil {
		db.Close()
		t.Fatal(err)
	}
	if err := db.Close(); err != nil {
		t.Fatal(err)
	}

	if err := sqlite.PrepareRestore(ctx, databasePath); err != nil {
		t.Fatalf("prepare version-two restore: %v", err)
	}
	migrated, err := sqlite.Open(ctx, databasePath)
	if err != nil {
		t.Fatal(err)
	}
	defer migrated.Close()
	if err := migrated.Ready(ctx); err != nil {
		t.Fatal(err)
	}
}
