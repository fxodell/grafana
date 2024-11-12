package cloudmigration

import (
	"context"

	"github.com/grafana/grafana/pkg/services/gcom"
	"github.com/grafana/grafana/pkg/services/user"
)

type Service interface {
	// GetToken Returns the cloud migration token if it exists.
	GetToken(ctx context.Context) (gcom.TokenView, error)
	// CreateToken Creates a cloud migration token.
	CreateToken(ctx context.Context) (CreateAccessTokenResponse, error)
	// ValidateToken Sends a request to GMS to test the token.
	ValidateToken(ctx context.Context, mig CloudMigrationSession) error
	DeleteToken(ctx context.Context, uid string) error

	CreateSession(ctx context.Context, req CloudMigrationSessionRequest) (*CloudMigrationSessionResponse, error)
	GetSession(ctx context.Context, orgID int64, migUID string) (*CloudMigrationSession, error)
	DeleteSession(ctx context.Context, orgID int64, migUID string) (*CloudMigrationSession, error)
	GetSessionList(ctx context.Context, orgID int64) (*CloudMigrationSessionListResponse, error)

	RunMigration(ctx context.Context, orgID int64, migUID string) (*MigrateDataResponse, error)
	GetMigrationStatus(ctx context.Context, runUID string) (*CloudMigrationSnapshot, error)
	GetMigrationRunList(ctx context.Context, migUID string) (*CloudMigrationRunList, error)

	CreateSnapshot(ctx context.Context, signedInUser *user.SignedInUser, sessionUid string) (*CloudMigrationSnapshot, error)
	GetSnapshot(ctx context.Context, query GetSnapshotsQuery) (*CloudMigrationSnapshot, error)
	GetSnapshotList(ctx context.Context, query ListSnapshotsQuery) ([]CloudMigrationSnapshot, error)
	UploadSnapshot(ctx context.Context, orgID int64, sessionUid string, snapshotUid string) error
	CancelSnapshot(ctx context.Context, sessionUid string, snapshotUid string) error
}
