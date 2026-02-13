# Configuration for the voice agent
CONFIG = {
    'language': 'en-IN',  # Indian English
    'sample_rate': 16000,
    'chunk_size': 1024,
    'recognition_timeout': 5,
    'questions': [
        "What kind of emergency are you facing?",
        "Where are you located right now?",
        "Is anyone injured?",
        "Are you in a safe place?",
        "Can you describe what happened?"
    ]
}

# Emergency type keywords (no AI needed)
EMERGENCY_KEYWORDS = {
    'accident': ['accident', 'crash', 'collision', 'hit', 'vehicle'],
    'medical': ['heart', 'chest pain', 'breathing', 'unconscious', 'stroke', 'seizure'],
    'fire': ['fire', 'smoke', 'burning', 'flames'],
    'assault': ['attack', 'assault', 'fight', 'violence']
}
