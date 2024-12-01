# Application settings
class Config:
    # Basic settings
    DEBUG = False
    TESTING = False
    SECRET_KEY = 'your-secret-key-here' # In production, use environment variable
    
    # Server settings
    HOST = '0.0.0.0'
    PORT = 80
    
    # Logging
    LOG_FILE = '/opt/confidant/logs/app.log'
    LOG_LEVEL = 'INFO'
    
    # Timeouts
    REQUEST_TIMEOUT = 30
    CONNECTION_TIMEOUT = 10

class DevelopmentConfig(Config):
    DEBUG = True
    LOG_LEVEL = 'DEBUG'

class ProductionConfig(Config):
    # Production uses the base configurations
    pass

class TestingConfig(Config):
    TESTING = True
    DEBUG = True

# Default configuration
config = {
    'development': DevelopmentConfig,
    'production': ProductionConfig,
    'testing': TestingConfig,
    'default': ProductionConfig
}