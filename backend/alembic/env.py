from __future__ import with_statement
import sys
import os
from logging.config import fileConfig

from sqlalchemy import engine_from_config
from sqlalchemy import pool

from alembic import context

# add project path so imports work
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

# this is the Alembic Config object, which provides
# access to the values within the .ini file in use.
config = context.config

# Interpret the config file for Python logging.
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

# Import your model's MetaData object here
from models.base import Base
import models.core  # noqa: F401  # poblar Base.metadata con las tablas del proyecto

target_metadata = Base.metadata

# Read the SQLALCHEMY URL from the project's config
try:
    from config.database import DATABASE_URL, DB_SSL, DB_SSL_CA
    config.set_main_option('sqlalchemy.url', DATABASE_URL)
except Exception:
    DB_SSL = False
    DB_SSL_CA = None


def run_migrations_offline():
    url = config.get_main_option("sqlalchemy.url")
    context.configure(url=url, target_metadata=target_metadata, literal_binds=True)

    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online():
    url = config.get_main_option("sqlalchemy.url")
    connect_args = {}
    if url and not url.startswith("sqlite") and DB_SSL:
        if DB_SSL_CA:
            connect_args["ssl"] = {"ca": DB_SSL_CA}
        else:
            connect_args["ssl"] = {"check_hostname": False}
    connectable = engine_from_config(
        config.get_section(config.config_ini_section),
        prefix='sqlalchemy.',
        poolclass=pool.NullPool,
        connect_args=connect_args,
    )

    with connectable.connect() as connection:
        context.configure(connection=connection, target_metadata=target_metadata)

        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
