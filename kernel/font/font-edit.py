# *****************************************************************************
# Copyright 2026 Stefan Jakobsson
#
# Redistribution and use in source and binary forms, with or without 
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice, 
#    this list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright notice, 
#    this list of conditions and the following disclaimer in the documentation 
#    and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" 
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE 
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE 
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN 
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
# POSSIBILITY OF SUCH DAMAGE.
# *****************************************************************************

import tkinter as tk

GRID_SIZE = 8
CELL_SIZE = 50
GLYPH_COUNT = 256
PREVIEW_SCALE = 2  # pixels per font pixel in the preview
PREVIEW_COLS = 16
PREVIEW_ROWS = GLYPH_COUNT // PREVIEW_COLS
PREVIEW_PAD = 3  # padding between glyphs in the preview
PREVIEW_GLYPH_PX = GRID_SIZE * PREVIEW_SCALE
PREVIEW_CELL_PX = PREVIEW_GLYPH_PX + PREVIEW_PAD


class FontEditor:
    def __init__(self, root):
        self.root = root
        self.root.title("X16 Font Editor")

        # Font data: 256 glyphs, each 8x8
        self.font = [[[0] * GRID_SIZE for _ in range(GRID_SIZE)] for _ in range(GLYPH_COUNT)]
        self.selected = 0

        # --- Layout ---
        main = tk.Frame(root)
        main.pack(padx=10, pady=10)

        # Left: preview panel
        preview_frame = tk.Frame(main)
        preview_frame.pack(side=tk.LEFT, padx=(0, 10))

        tk.Label(preview_frame, text="Glyphs", font=("monospace", 11, "bold")).pack()

        preview_w = PREVIEW_COLS * PREVIEW_CELL_PX - PREVIEW_PAD
        preview_h = PREVIEW_ROWS * PREVIEW_CELL_PX - PREVIEW_PAD

        preview_container = tk.Frame(preview_frame)
        preview_container.pack()

        self.preview_canvas = tk.Canvas(
            preview_container, width=preview_w, height=preview_h,
            bg="#222", highlightthickness=0,
        )
        self.preview_canvas.pack(side=tk.LEFT)
        self.preview_canvas.bind("<Button-1>", self.on_preview_click)

        scrollbar = tk.Scrollbar(preview_container, orient=tk.VERTICAL,
                                 command=self.preview_canvas.yview)
        self.preview_canvas.configure(
            scrollregion=(0, 0, preview_w, preview_h),
            yscrollcommand=scrollbar.set,
        )

        self.glyph_label = tk.Label(preview_frame, text="Selected: 0 (0x00)", font=("monospace", 10))
        self.glyph_label.pack(pady=(4, 0))

        # Right: editor panel
        editor_frame = tk.Frame(main)
        editor_frame.pack(side=tk.LEFT)

        tk.Label(editor_frame, text="Editor", font=("monospace", 11, "bold")).pack()

        canvas_size = GRID_SIZE * CELL_SIZE
        self.canvas = tk.Canvas(editor_frame, width=canvas_size, height=canvas_size, bg="white")
        self.canvas.pack()
        self.canvas.bind("<Button-1>", self.on_editor_click)
        self.canvas.bind("<B1-Motion>", self.on_editor_drag)
        self.canvas.bind("<Button-3>", self.on_editor_right_click)
        self.canvas.bind("<B3-Motion>", self.on_editor_right_drag)

        btn_frame = tk.Frame(editor_frame)
        btn_frame.pack(pady=6)
        tk.Button(btn_frame, text="Clear Glyph", command=self.clear_glyph).pack(side=tk.LEFT, padx=4)
        tk.Button(btn_frame, text="Invert Glyph", command=self.invert_glyph).pack(side=tk.LEFT, padx=4)
        tk.Button(btn_frame, text="Export Font", command=self.export_font).pack(side=tk.LEFT, padx=4)
        tk.Button(btn_frame, text="Import Font", command=self.import_font).pack(side=tk.LEFT, padx=4)

        self.draw_editor()
        self.draw_preview()

    # --- Editor ---

    def draw_editor(self):
        self.canvas.delete("all")
        glyph = self.font[self.selected]
        for row in range(GRID_SIZE):
            for col in range(GRID_SIZE):
                x0 = col * CELL_SIZE
                y0 = row * CELL_SIZE
                fill = "black" if glyph[row][col] else "white"
                self.canvas.create_rectangle(
                    x0, y0, x0 + CELL_SIZE, y0 + CELL_SIZE,
                    fill=fill, outline="gray",
                )

    def _set_pixel(self, event, value):
        col = event.x // CELL_SIZE
        row = event.y // CELL_SIZE
        if 0 <= row < GRID_SIZE and 0 <= col < GRID_SIZE:
            if self.font[self.selected][row][col] != value:
                self.font[self.selected][row][col] = value
                self.draw_editor()
                self.draw_preview_glyph(self.selected)

    def on_editor_click(self, event):
        col = event.x // CELL_SIZE
        row = event.y // CELL_SIZE
        if 0 <= row < GRID_SIZE and 0 <= col < GRID_SIZE:
            self.font[self.selected][row][col] ^= 1
            self.draw_editor()
            self.draw_preview_glyph(self.selected)

    def on_editor_drag(self, event):
        self._set_pixel(event, 1)

    def on_editor_right_click(self, event):
        self._set_pixel(event, 0)

    def on_editor_right_drag(self, event):
        self._set_pixel(event, 0)

    # --- Preview ---

    def draw_preview(self):
        self.preview_canvas.delete("all")
        for i in range(GLYPH_COUNT):
            self._draw_preview_glyph_at(i)
        self._draw_selection_box()

    def draw_preview_glyph(self, index):
        """Redraw a single glyph in the preview."""
        tag = f"glyph_{index}"
        self.preview_canvas.delete(tag)
        self._draw_preview_glyph_at(index, tag)
        self._draw_selection_box()

    def _draw_preview_glyph_at(self, index, tag=None):
        col = index % PREVIEW_COLS
        row = index // PREVIEW_COLS
        x0 = col * PREVIEW_CELL_PX
        y0 = row * PREVIEW_CELL_PX
        glyph = self.font[index]

        # Background
        self.preview_canvas.create_rectangle(
            x0, y0, x0 + PREVIEW_GLYPH_PX, y0 + PREVIEW_GLYPH_PX,
            fill="#222", outline="#333", tags=tag,
        )

        # Pixels
        for r in range(GRID_SIZE):
            for c in range(GRID_SIZE):
                if glyph[r][c]:
                    px = x0 + c * PREVIEW_SCALE
                    py = y0 + r * PREVIEW_SCALE
                    self.preview_canvas.create_rectangle(
                        px, py, px + PREVIEW_SCALE, py + PREVIEW_SCALE,
                        fill="white", outline="", tags=tag,
                    )

    def _draw_selection_box(self):
        self.preview_canvas.delete("selection")
        col = self.selected % PREVIEW_COLS
        row = self.selected // PREVIEW_COLS
        x0 = col * PREVIEW_CELL_PX
        y0 = row * PREVIEW_CELL_PX
        self.preview_canvas.create_rectangle(
            x0, y0, x0 + PREVIEW_GLYPH_PX, y0 + PREVIEW_GLYPH_PX,
            outline="#00ff00", width=2, tags="selection",
        )

    def on_preview_click(self, event):
        col = event.x // PREVIEW_CELL_PX
        row = event.y // PREVIEW_CELL_PX
        index = row * PREVIEW_COLS + col
        if 0 <= index < GLYPH_COUNT:
            self.selected = index
            self.glyph_label.config(text=f"Selected: {index} (0x{index:02X})")
            self.draw_editor()
            self._draw_selection_box()

    # --- Glyph operations ---

    def clear_glyph(self):
        self.font[self.selected] = [[0] * GRID_SIZE for _ in range(GRID_SIZE)]
        self.draw_editor()
        self.draw_preview_glyph(self.selected)

    def invert_glyph(self):
        glyph = self.font[self.selected]
        for r in range(GRID_SIZE):
            for c in range(GRID_SIZE):
                glyph[r][c] ^= 1
        self.draw_editor()
        self.draw_preview_glyph(self.selected)

    # --- Import / Export ---

    def export_font(self):
        """Export font as ca65 .byt directives, one glyph per line."""
        for i, glyph in enumerate(self.font):
            bytes_list = []
            for row in glyph:
                byte = 0
                for bit in row:
                    byte = (byte << 1) | bit
                bytes_list.append(f"${byte:02X}")
            print(f".byt {','.join(bytes_list)}  ; {i} (0x{i:02X})")

    def import_font(self):
        """Open a dialog to paste ca65 .byt lines."""
        import re
        win = tk.Toplevel(self.root)
        win.title("Import Font")
        tk.Label(win, text="Paste .byt lines below:").pack(padx=10, pady=(10, 0))
        text = tk.Text(win, width=70, height=20)
        text.pack(padx=10, pady=6)

        def do_import():
            content = text.get("1.0", tk.END)
            glyph_index = 0
            for line in content.splitlines():
                line = line.split(";")[0].strip()
                if not line.lower().startswith(".byt"):
                    continue
                values = re.findall(r'\$([0-9A-Fa-f]+)', line)
                if len(values) < GRID_SIZE:
                    continue
                for r in range(GRID_SIZE):
                    byte = int(values[r], 16)
                    for c in range(GRID_SIZE):
                        self.font[glyph_index][r][c] = (byte >> (7 - c)) & 1
                glyph_index += 1
                if glyph_index >= GLYPH_COUNT:
                    break
            self.draw_editor()
            self.draw_preview()
            print(f"Imported {glyph_index} glyphs")
            win.destroy()

        tk.Button(win, text="Import", command=do_import).pack(pady=(0, 10))


if __name__ == "__main__":
    root = tk.Tk()
    app = FontEditor(root)
    root.mainloop()
