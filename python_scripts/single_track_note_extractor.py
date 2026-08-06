import pretty_midi
import os
import sys

# Chromatic run corresponds 1:1 to the wav files in a Godot instrument
# library folder (libraries/<instrument>/*.wav) -- NOT real octaves,
# the L/H/HH prefixes just disambiguate repeated letter names across
# one contiguous chromatic run. This list matches audio_player.gd's
# guitar preloads (ld...hhe, 39 notes) -- update it if the library's
# note range changes.
NOTE_NAMES = [
    "ld", "ld_sharp", "le", "lf", "lf_sharp", "lg", "lg_sharp",
    "a", "a_sharp", "b", "c", "c_sharp", "d", "d_sharp", "e", "f", "f_sharp", "g", "g_sharp",
    "ha", "ha_sharp", "hb", "hc", "hc_sharp", "hd", "hd_sharp", "he", "hf", "hf_sharp", "hg", "hg_sharp",
    "hha", "hha_sharp", "hhb", "hhc", "hhc_sharp", "hhd", "hhd_sharp", "hhe",
]

MIDI_DIR = "Mids"
OUTPUT_DIR = "../musictxts"  # matches audio_player.gd's SONG_DIR (res://musictxts/)


def pick_melody_instrument(midi_data):
    """Heuristic for picking the lead/melody track when there's no
    reliable track name to go on: the instrument with the highest
    average note pitch is assumed to carry the melody. Drum tracks and
    empty instruments are skipped."""
    best = None
    best_avg_pitch = -1.0
    for instrument in midi_data.instruments:
        if instrument.is_drum or not instrument.notes:
            continue
        avg_pitch = sum(note.pitch for note in instrument.notes) / len(instrument.notes)
        if avg_pitch > best_avg_pitch:
            best_avg_pitch = avg_pitch
            best = instrument
    return best


def flatten_to_monophonic(instrument):
    """Collapses chords/overlapping notes to a single monophonic line
    by keeping only the top (highest-pitch) note at each onset time."""
    notes_by_start = {}
    for note in instrument.notes:
        existing = notes_by_start.get(note.start)
        if existing is None or note.pitch > existing.pitch:
            notes_by_start[note.start] = note
    return [notes_by_start[start] for start in sorted(notes_by_start)]


def fold_to_range(pitch, anchor, num_notes):
    """Octave-folds a pitch (+/-12 repeatedly) until it lands inside
    [anchor, anchor + num_notes - 1]. Used to keep any out-of-range
    note within the target library's span."""
    highest_pitch = anchor + num_notes - 1
    while pitch < anchor:
        pitch += 12
    while pitch > highest_pitch:
        pitch -= 12
    return pitch


def center_fold_window(pitches, num_notes, max_iters=8):
    """Picks the fold-window anchor (bottom) so the melody's average
    pitch lands on the middle of the library's note range. Re-centers
    iteratively because octave-folding shifts the average; returns the
    anchor whose folded average sits closest to center, since integer
    window boundaries can't always hit exact center when a note
    straddles a fold edge."""
    center_index = (num_notes - 1) / 2.0
    avg_pitch = sum(pitches) / len(pitches)
    anchor = round(avg_pitch - center_index)
    best = (anchor, float("inf"))
    for _ in range(max_iters):
        folded = [fold_to_range(p, anchor, num_notes) for p in pitches]
        folded_avg = sum(folded) / len(folded)
        residual = abs((anchor + center_index) - folded_avg)
        if residual < best[1]:
            best = (anchor, residual)
        if residual < 0.5:
            break
        anchor = round(anchor + ((anchor + center_index) - folded_avg))
    return best[0]


def extract_song(midi_path, output_dir=OUTPUT_DIR, note_names=NOTE_NAMES):
    """Extracts a monophonic melody from midi_path and writes it as
    <output_dir>/<song_name>.txt in the comma/semicolon note-name
    format audio_player.gd's load_song() reads. Returns True on
    success, False if the file couldn't be processed."""
    midi_data = pretty_midi.PrettyMIDI(midi_path)
    song_name = os.path.splitext(os.path.basename(midi_path))[0]

    melody = pick_melody_instrument(midi_data)
    if melody is None:
        print(f"  no usable (non-drum, non-empty) instrument found in {midi_path} -- skipping")
        return False

    monophonic_notes = flatten_to_monophonic(melody)
    if not monophonic_notes:
        print(f"  melody instrument has no notes in {midi_path} -- skipping")
        return False

    # center the fold window on the melody's own average pitch so the
    # song's average tone lands on the middle of the library's range
    # rather than anchoring its lowest note to the library's lowest
    num_notes = len(note_names)
    anchor = center_fold_window([note.pitch for note in monophonic_notes], num_notes)

    note_sequence = []
    folded_count = 0
    for note in monophonic_notes:
        folded_pitch = fold_to_range(note.pitch, anchor, num_notes)
        if folded_pitch != note.pitch:
            folded_count += 1
        offset = folded_pitch - anchor
        note_sequence.append(note_names[offset])

    os.makedirs(output_dir, exist_ok=True)
    out_path = os.path.join(output_dir, song_name + ".txt")
    with open(out_path, "w") as f:
        f.write(",".join(note_sequence))
        f.write(";")

    fold_note = f", {folded_count} note(s) octave-folded to fit" if folded_count else ""
    print(f"  wrote {out_path} ({len(note_sequence)} notes{fold_note})")
    return True


def main():
    # Usage:
    #   python single_track_note_extractor.py moonlight1.mid mario.mid
    #   python single_track_note_extractor.py                 (processes every .mid in Mids/)
    if len(sys.argv) > 1:
        midi_files = sys.argv[1:]
    else:
        if not os.path.isdir(MIDI_DIR):
            print(f"no MIDI files given and '{MIDI_DIR}/' doesn't exist")
            return
        midi_files = [f for f in os.listdir(MIDI_DIR) if f.lower().endswith(".mid")]
        if not midi_files:
            print(f"no .mid files found in '{MIDI_DIR}/'")
            return

    for midi_file in midi_files:
        if os.path.isabs(midi_file) or os.path.dirname(midi_file):
            midi_path = midi_file
        else:
            midi_path = os.path.join(MIDI_DIR, midi_file)
        print(f"processing {midi_path}...")
        extract_song(midi_path)


if __name__ == "__main__":
    main()