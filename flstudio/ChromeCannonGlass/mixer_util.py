"""Pure helpers for FL Studio mixer + piano-roll volume scripts.

FL MIDI scripts and piano-roll scripts cannot share a runtime (different
module sets). This file is imported by tests and by the MIDI device script
when it lives in the same hardware folder.
"""

UNITY = 0.8
MAX_VOLUME = 1.0  # mixer.setTrackVolume range


def clamp_volume(value, lo=0.0, hi=MAX_VOLUME):
    try:
        v = float(value)
    except (TypeError, ValueError):
        v = 0.0
    return max(lo, min(hi, v))


def midi_cc_to_volume(data2):
    """127 → 1.0, 0 → 0.0 (standard MIDI CC fader)."""
    try:
        n = int(data2)
    except (TypeError, ValueError):
        n = 0
    return clamp_volume(n / 127.0)


def volume_to_midi_cc(volume):
    return int(round(clamp_volume(volume) * 127))


def apply_all_track_volumes(set_track_volume, track_count, level=UNITY):
    """Set Master (index 0) and every mixer track to `level` (default 80%)."""
    level = clamp_volume(level)
    count = max(1, int(track_count or 1))
    for index in range(count):
        set_track_volume(index, level)
    return count


def iter_score_notes(score):
    """Yield notes from a piano-roll score (notes list or getNote API)."""
    notes = getattr(score, "notes", None)
    if notes is not None:
        for note in notes:
            yield note
        return
    count = int(getattr(score, "noteCount", 0) or 0)
    get_note = getattr(score, "getNote", None)
    if get_note is None:
        return
    for i in range(count):
        yield get_note(i)


def set_all_note_velocities(score, velocity=UNITY):
    """Set every piano-roll note velocity to `velocity` (0–1, default 0.8)."""
    velocity = clamp_volume(velocity)
    n = 0
    for note in iter_score_notes(score):
        note.velocity = velocity
        n += 1
    return n
