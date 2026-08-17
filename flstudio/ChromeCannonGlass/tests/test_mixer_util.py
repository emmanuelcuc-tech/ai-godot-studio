# Headless tests for FL mixer_util (no FL Studio required).
# Run: python3 flstudio/ChromeCannonGlass/tests/test_mixer_util.py

import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))

import mixer_util as mu  # noqa: E402


class FakeNote:
    def __init__(self, v=0.1):
        self.velocity = v


class FakeScoreNotes:
    def __init__(self, n):
        self.notes = [FakeNote(0.1) for _ in range(n)]


class FakeScoreIndexed:
    def __init__(self, n):
        self._notes = [FakeNote(0.2) for _ in range(n)]
        self.noteCount = n

    def getNote(self, i):
        return self._notes[i]


class MixerUtilTests(unittest.TestCase):
    def test_midi_cc_to_volume(self):
        self.assertAlmostEqual(mu.midi_cc_to_volume(0), 0.0)
        self.assertAlmostEqual(mu.midi_cc_to_volume(127), 1.0)
        self.assertAlmostEqual(mu.midi_cc_to_volume(64), 64 / 127)

    def test_volume_to_midi_roundtrip(self):
        self.assertEqual(mu.volume_to_midi_cc(1), 127)
        self.assertEqual(mu.volume_to_midi_cc(0), 0)

    def test_apply_all_includes_master(self):
        written = {}

        def set_vol(i, v):
            written[i] = v

        n = mu.apply_all_track_volumes(set_vol, 5, 0.8)
        self.assertEqual(n, 5)
        self.assertEqual(written[0], 0.8)  # master
        self.assertEqual(written[4], 0.8)

    def test_piano_roll_notes_list(self):
        score = FakeScoreNotes(3)
        n = mu.set_all_note_velocities(score, 0.8)
        self.assertEqual(n, 3)
        self.assertTrue(all(note.velocity == 0.8 for note in score.notes))

    def test_piano_roll_getNote(self):
        score = FakeScoreIndexed(4)
        n = mu.set_all_note_velocities(score, 0.8)
        self.assertEqual(n, 4)
        self.assertEqual(score.getNote(0).velocity, 0.8)


if __name__ == "__main__":
    unittest.main(verbosity=2)
