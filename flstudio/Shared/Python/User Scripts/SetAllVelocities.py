# Piano roll script — User Scripts context only (flpianoroll, enveditor).
# MIDI modules are unavailable in this sandbox.
#
# Install: Shared\Python\User Scripts\SetAllVelocities.py
# Run: open a pattern in the piano roll → Scripts menu.

import flpianoroll

score = flpianoroll.score
for note in score.notes:
    note.velocity = 0.8  # Set all velocities to 80%
