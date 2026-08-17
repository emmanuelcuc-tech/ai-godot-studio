# Piano roll script — set every note velocity to 80% (FL default / unity).
# Copy to Shared\Python\User Scripts\ (canonical copy lives there).
# Mixer/Master volumes belong in device_ChromeCannonGlass.py.

import flpianoroll

score = flpianoroll.score
for note in score.notes:
    note.velocity = 0.8  # Set all velocities to 80%
