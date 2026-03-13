# awx/settings.py
# ============================================================
# AWX Custom Settings
# Mounted into both awx-web and awx-task containers at:
#   /etc/tower/conf.d/custom.py
#
# These override AWX defaults. All sensitive values come from
# environment variables (never hardcoded here).
# ============================================================
import os

# ── Database ──────────────────────────────────────────────────
DATABASES = {
    'default': {
        'ATOMIC_REQUESTS': True,
        'ENGINE': 'awx.main.db.profiled_pg',
        'NAME':     os.environ.get('DATABASE_NAME', 'awx'),
        'USER':     os.environ.get('DATABASE_USER', 'awx'),
        'PASSWORD': os.environ.get('DATABASE_PASSWORD', ''),
        'HOST':     os.environ.get('DATABASE_HOST', 'postgres'),
        'PORT':     os.environ.get('DATABASE_PORT', '5432'),
        'OPTIONS': {
            'sslmode': 'prefer',
            # Keep-alive for long-running Ansible jobs
            'keepalives': 1,
            'keepalives_idle': 5,
            'keepalives_interval': 5,
            'keepalives_count': 5,
        },
        'CONN_MAX_AGE': 0,
    }
}

# ── Redis / Channel Layers ────────────────────────────────────
REDIS_HOST = os.environ.get('REDIS_HOST', 'redis')
REDIS_PORT = int(os.environ.get('REDIS_PORT', 6379))

CHANNEL_LAYERS = {
    'default': {
        'BACKEND': 'channels_redis.core.RedisChannelLayer',
        'CONFIG': {
            'hosts': [(REDIS_HOST, REDIS_PORT)],
            'capacity': 10000,
            'expiry': 60,
        }
    }
}

CACHES = {
    'default': {
        'BACKEND': 'django_redis.cache.RedisCache',
        'LOCATION': f'redis://{REDIS_HOST}:{REDIS_PORT}/1',
        'OPTIONS': {
            'CLIENT_CLASS': 'django_redis.client.DefaultClient',
        }
    }
}

# ── Security ──────────────────────────────────────────────────
# Set to True when serving over HTTPS
SESSION_COOKIE_SECURE = os.environ.get('SESSION_COOKIE_SECURE', 'False') == 'True'
CSRF_COOKIE_SECURE    = os.environ.get('CSRF_COOKIE_SECURE', 'False') == 'True'

# Allowed hosts — add your server IP or domain here
ALLOWED_HOSTS = ['*']  # Restrict in production: ['awx.example.com', '10.0.1.5']

# ── AWX Task Environment ──────────────────────────────────────
# Environment variables passed to Ansible job execution
AWX_TASK_ENV = {
    'GIT_SSL_NO_VERIFY': 'false',
    # Add proxy settings if needed:
    # 'HTTP_PROXY':  'http://proxy.example.com:3128',
    # 'HTTPS_PROXY': 'http://proxy.example.com:3128',
    # 'NO_PROXY':    'localhost,127.0.0.1',
}

# ── Logging ───────────────────────────────────────────────────
LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'formatters': {
        'simple': {
            'format': '%(asctime)s %(levelname)-8s %(name)s %(message)s',
            'datefmt': '%Y-%m-%d %H:%M:%S',
        },
    },
    'handlers': {
        'console': {
            'class': 'logging.StreamHandler',
            'formatter': 'simple',
        },
    },
    'root': {
        'handlers': ['console'],
        'level': os.environ.get('AWX_LOG_LEVEL', 'WARNING'),
    },
    'loggers': {
        'django': {
            'handlers': ['console'],
            'level': 'WARNING',
            'propagate': False,
        },
        'awx': {
            'handlers': ['console'],
            'level': os.environ.get('AWX_LOG_LEVEL', 'WARNING'),
            'propagate': False,
        },
    },
}

# ── Performance ───────────────────────────────────────────────
# Number of concurrent Ansible jobs
AWX_CONCURRENT_JOBS_LIMIT = int(os.environ.get('AWX_CONCURRENT_JOBS', '10'))

# Job output event processing
JOB_EVENT_WORKERS = int(os.environ.get('JOB_EVENT_WORKERS', '4'))
