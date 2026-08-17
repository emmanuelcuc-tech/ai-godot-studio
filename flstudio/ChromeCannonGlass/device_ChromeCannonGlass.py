# name=Chrome Cannon Glass Mixer
# url=https://github.com/emmanuelcuc-tech/ai-godot-studio
"""MIDI controller script (FL Studio 20.8.4+).

Context: MIDI only — modules general, mixer, device, transport.
Piano-roll APIs belong in User Scripts, not this file.

Install:
  Documents/Image-Line/FL Studio/Settings/Hardware/Chrome Cannon Glass/device_ChromeCannonGlass.py
"""

import general
import device
import mixer
import transport

UNITY = 0.8  # FL default / 0 dB
MASTER_TRACK = 0
CC_VOLUME = 7          # current mixer track
CC_MASTER = 8          # Master (track 0)
CC_SET_ALL_UNITY = 64  # set every track including Master to 80%


def OnInit():
    """Called when script starts."""
    print(f"API Version: {general.getVersion()}")
    if not device.isAssigned():
        print("No output device linked!")
        return
    print(f"Connected: {device.getName()}")
    mixer.setHasMeters()


def OnDeInit():
    """Called when script stops."""
    print("Script shut down")


def OnMidiMsg(msg):
    """Called for incoming MIDI messages."""
    pass


def OnControlChange(msg):
    """Called for CC messages."""
    cc = msg.data1
    value = msg.data2 / 127.0

    if cc == CC_SET_ALL_UNITY and msg.data2 > 0:
        count = mixer.trackCount()
        for index in range(count):
            mixer.setTrackVolume(index, UNITY)
        print(f"Set all {count} mixer tracks (incl. Master) to {UNITY}")
        msg.handled = True
        return

    if cc == CC_MASTER:
        mixer.setTrackVolume(MASTER_TRACK, value)
        msg.handled = True
        return

    if cc == CC_VOLUME:
        mixer.setTrackVolume(mixer.trackNumber(), value)
        msg.handled = True


def OnNoteOn(msg):
    """Called for note-on messages."""
    if msg.data2 <= 0:
        return
    track = msg.data1 % 8
    mixer.setActiveTrack(track)
    msg.handled = True


def OnRefresh(flags):
    """Called when FL Studio state changes."""
    if device.isAssigned():
        vol = mixer.getTrackVolume(MASTER_TRACK)
        cc = int(vol * 127)
        device.midiOutMsg(0xB0, 0, CC_VOLUME, cc)
        # Pad LED velocity = volume height (red note-on)
        device.midiOutMsg(0x90, 0, 60, cc)
