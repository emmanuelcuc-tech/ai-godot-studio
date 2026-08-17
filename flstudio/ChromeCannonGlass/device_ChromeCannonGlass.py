# name=Chrome Cannon Glass Mixer
# receiveFrom=Chrome Cannon Glass
"""FL Studio MIDI script — Master + all mixer volumes.

Install:
  Documents/Image-Line/FL Studio/Settings/Hardware/Chrome Cannon Glass/
    device_ChromeCannonGlass.py
    mixer_util.py

Bind a MIDI fader to CC7. Channel 1 (index 0) is Master; other channels
map to mixer tracks. CC 64 "set all" dumps every track (including Master)
to unity 0.8.

MIDI scripts cannot import flpianoroll — use SetAllVelocities.py in the
piano-roll Scripts menu for note velocities.
"""

import general
import mixer
import device

try:
    import midi
except ImportError:
    midi = None

try:
    from mixer_util import (
        UNITY,
        apply_all_track_volumes,
        midi_cc_to_volume,
        volume_to_midi_cc,
    )
except ImportError:
    UNITY = 0.8

    def midi_cc_to_volume(data2):
        try:
            return max(0.0, min(1.0, int(data2) / 127.0))
        except (TypeError, ValueError):
            return 0.0

    def volume_to_midi_cc(volume):
        return int(round(max(0.0, min(1.0, float(volume))) * 127))

    def apply_all_track_volumes(set_track_volume, track_count, level=UNITY):
        count = max(1, int(track_count or 1))
        for i in range(count):
            set_track_volume(i, level)
        return count

MASTER_TRACK = 0
CC_VOLUME = 7
CC_SET_ALL_UNITY = 64


def _log(msg):
    print("[ChromeCannonGlass] " + str(msg))


def _api_version():
    try:
        return general.getVersion()
    except TypeError:
        return general.getVersion(4)
    except Exception as exc:
        return "unknown (%s)" % exc


def OnInit():
    """Called when the script starts."""
    _log("API Version: %s" % _api_version())
    try:
        mixer.setHasMeters()
    except Exception:
        pass
    if device.isAssigned():
        _log("Connected: %s" % device.getName())
    else:
        _log("No output device linked (meters/feedback skipped).")


def OnDeInit():
    """Called when the script stops."""
    _log("stopped")


def OnMidiMsg(event):
    """Incoming MIDI. CC7 = volume (ch1 Master). CC64 = set all to 80%."""
    status = getattr(event, "status", 0) or 0
    midi_id = getattr(event, "midiId", None)
    is_cc = False
    if midi is not None and midi_id is not None:
        is_cc = midi_id == getattr(midi, "MIDI_CONTROLCHANGE", 0xB0)
    if (status & 0xF0) == 0xB0:
        is_cc = True
    if not is_cc:
        return

    cc = getattr(event, "data1", 0)
    value = getattr(event, "data2", 0)
    chan = getattr(event, "midiChan", None)
    if chan is None:
        chan = status & 0x0F

    if cc == CC_SET_ALL_UNITY and value > 0:
        n = apply_all_track_volumes(mixer.setTrackVolume, mixer.trackCount(), UNITY)
        _log("set all %d tracks (incl. Master) to %.2f" % (n, UNITY))
        event.handled = True
        return

    if cc != CC_VOLUME:
        return

    vol = midi_cc_to_volume(value)
    track = MASTER_TRACK if chan <= 0 else chan
    try:
        count = mixer.trackCount()
        if track >= count:
            track = MASTER_TRACK
        mixer.setTrackVolume(track, vol)
        event.handled = True
        _log("track %d volume %.2f" % (track, vol))
    except Exception as exc:
        _log("setTrackVolume failed: %s" % exc)


def OnControlChange(event):
    """CC messages not consumed by OnMidiMsg."""
    OnMidiMsg(event)


def OnNoteOn(event):
    """Note-on: pick mixer track (note % trackCount), skip Master for notes."""
    note = getattr(event, "data1", 0) or 0
    vel = getattr(event, "data2", 0) or 0
    if vel <= 0:
        return
    try:
        count = mixer.trackCount()
        if count <= 1:
            mixer.setActiveTrack(MASTER_TRACK)
        else:
            mixer.setActiveTrack(1 + (note % (count - 1)))
        event.handled = True
    except Exception:
        pass


def OnRefresh(flags):
    """Push Master volume back to the controller (CC7 ch1)."""
    if not device.isAssigned():
        return
    try:
        vol = mixer.getTrackVolume(MASTER_TRACK)
        cc = volume_to_midi_cc(vol)
        device.midiOutMsg(0xB0, 0, CC_VOLUME, cc)
    except Exception:
        pass
