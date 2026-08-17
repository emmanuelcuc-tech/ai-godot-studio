# Piano roll script — set every note velocity to 80% (FL default / unity).
# Scripts → Piano roll → run this. Does not work as a MIDI device script
# (flpianoroll is not available there; use device_ChromeCannonGlass.py instead).

import flpianoroll

UNITY = 0.8
score = flpianoroll.score
count = 0

notes = getattr(score, "notes", None)
if notes is not None:
    for note in notes:
        note.velocity = UNITY
        count += 1
elif hasattr(score, "noteCount") and hasattr(score, "getNote"):
    for i in range(score.noteCount):
        score.getNote(i).velocity = UNITY
        count += 1

print("Set %d piano-roll notes to velocity %.2f" % (count, UNITY))
