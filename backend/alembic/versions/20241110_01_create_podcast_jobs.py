"""create podcast_jobs table

Revision ID: 1e7ba5b35f84
Revises: 
Create Date: 2025-11-10 05:55:00.000000
"""

from __future__ import annotations

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = "1e7ba5b35f84"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    podcast_job_status = sa.Enum(
        "queued",
        "running",
        "succeeded",
        "failed",
        name="podcast_job_status",
        native_enum=False,
    )
    podcast_job_status.create(op.get_bind(), checkfirst=True)

    op.create_table(
        "podcast_jobs",
        sa.Column("id", sa.String(), primary_key=True, nullable=False),
        sa.Column("status", podcast_job_status, nullable=False, server_default=sa.text("'queued'")),
        sa.Column("requested_by", sa.Text(), nullable=True),
        sa.Column("payload", sa.JSON(), nullable=False),
        sa.Column("result_paths", sa.JSON(), nullable=True),
        sa.Column("error_message", sa.Text(), nullable=True),
        sa.Column("progress", sa.Integer(), nullable=True),
        sa.Column("log_excerpt", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.CheckConstraint(
            "progress IS NULL OR (progress >= 0 AND progress <= 100)",
            name="podcast_jobs_progress_range",
        ),
    )


def downgrade() -> None:
    op.drop_table("podcast_jobs")
    podcast_job_status = sa.Enum(
        "queued",
        "running",
        "succeeded",
        "failed",
        name="podcast_job_status",
        native_enum=False,
    )
    podcast_job_status.drop(op.get_bind(), checkfirst=True)
