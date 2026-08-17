# Edison audio script — User Scripts / Edison context only (`enveditor`).
# MIDI modules and flpianoroll are not available here.

try:
    import enveditor
    print("Edison enveditor ready")
except ImportError:
    print("Run this script from Edison")
