import json
import os
import threading
from pathlib import Path
from tkinter import filedialog, messagebox, ttk
import tkinter as tk

import cv2
import numpy as np
from PIL import Image, ImageTk


class App:
    def __init__(self, root):
        self.root = root
        self.root.title("Comparador de Cabo - Modelo x Vídeo")
        self.root.geometry("750x520")
        self.root.minsize(700, 480)

        self.model_path = tk.StringVar(value="")
        self.video_path = tk.StringVar(value="")
        self.output_dir = tk.StringVar(value=str(Path.cwd() / "resultados"))
        self.threshold = tk.DoubleVar(value=5.0)

        self._build_ui()

    def _build_ui(self):
        container = ttk.Frame(self.root, padding=18)
        container.pack(fill="both", expand=True)

        title = ttk.Label(
            container,
            text="Comparação de foto modelo x vídeo",
            font=("Segoe UI", 18, "bold"),
        )
        title.pack(anchor="w", pady=(0, 18))

        fields = ttk.Frame(container)
        fields.pack(fill="x")

        self._add_file_field(fields, "Foto modelo", self.model_path, "*.png;*.jpg;*.jpeg;*.bmp")
        self._add_file_field(fields, "Vídeo", self.video_path, "*.mp4;*.avi;*.mov;*.mkv;*.wmv")
        self._add_dir_field(fields, "Pasta de saída", self.output_dir)

        controls = ttk.Frame(container)
        controls.pack(fill="x", pady=(18, 10))

        ttk.Label(controls, text="Tolerância máxima de diferença (%):").grid(row=0, column=0, sticky="w")
        self.threshold_spin = ttk.Spinbox(
            controls,
            from_=0.1,
            to=100.0,
            increment=0.5,
            textvariable=self.threshold,
            width=10,
        )
        self.threshold_spin.grid(row=0, column=1, padx=(10, 20), sticky="w")

        action_row = ttk.Frame(container)
        action_row.pack(fill="x")

        self.run_button = ttk.Button(action_row, text="Iniciar comparação", command=self.start_analysis)
        self.run_button.pack(side="left", padx=(0, 10))

        ttk.Button(action_row, text="Limpar", command=self.clear_form).pack(side="left")

        result_group = ttk.LabelFrame(container, text="Resultado")
        result_group.pack(fill="both", expand=True, pady=(12, 0))

        self.result_text = tk.Text(result_group, height=14, wrap="word", state="disabled")
        self.result_text.pack(fill="both", expand=True, padx=10, pady=10)

    def _add_file_field(self, parent, label, var, filetypes):
        row = ttk.Frame(parent)
        row.pack(fill="x", pady=6)

        ttk.Label(row, text=f"{label}:", width=16, anchor="w").pack(side="left")

        entry = ttk.Entry(row, textvariable=var)
        entry.pack(side="left", fill="x", expand=True, padx=(8, 8))

        ttk.Button(row, text="Procurar", command=lambda: self._select_file(var, filetypes)).pack(side="left")

    def _add_dir_field(self, parent, label, var):
        row = ttk.Frame(parent)
        row.pack(fill="x", pady=6)

        ttk.Label(row, text=f"{label}:", width=16, anchor="w").pack(side="left")

        entry = ttk.Entry(row, textvariable=var)
        entry.pack(side="left", fill="x", expand=True, padx=(8, 8))

        ttk.Button(row, text="Selecionar", command=lambda: self._select_directory(var)).pack(side="left")

    def _select_file(self, var, filetypes):
        path = filedialog.askopenfilename(filetypes=[("Arquivos suportados", filetypes)])
        if path:
            var.set(path)

    def _select_directory(self, var):
        directory = filedialog.askdirectory()
        if directory:
            var.set(directory)

    def clear_form(self):
        self.model_path.set("")
        self.video_path.set("")
        self.output_dir.set(str(Path.cwd() / "resultados"))
        self.threshold.set(5.0)
        self._set_result("Nenhuma análise realizada ainda.")

    def _set_result(self, text):
        self.result_text.configure(state="normal")
        self.result_text.delete(1.0, tk.END)
        self.result_text.insert(tk.END, text)
        self.result_text.configure(state="disabled")

    def start_analysis(self):
        model_path = self.model_path.get().strip()
        video_path = self.video_path.get().strip()
        output_dir = self.output_dir.get().strip()

        if not model_path or not video_path:
            messagebox.showwarning("Campos obrigatórios", "Selecione a foto modelo e o vídeo antes de continuar.")
            return

        if not os.path.exists(model_path):
            messagebox.showerror("Arquivo inexistente", "A foto modelo não foi encontrada.")
            return

        if not os.path.exists(video_path):
            messagebox.showerror("Arquivo inexistente", "O vídeo não foi encontrado.")
            return

        if not output_dir:
            output_dir = str(Path.cwd() / "resultados")

        os.makedirs(output_dir, exist_ok=True)

        self.run_button.config(state="disabled")
        self._set_result("Analisando vídeo... aguarde...")

        threading.Thread(
            target=self._process_video,
            args=(model_path, video_path, output_dir, float(self.threshold.get())),
            daemon=True,
        ).start()

    def _process_video(self, model_path, video_path, output_dir, threshold_percent):
        try:
            model_image = cv2.imread(model_path, cv2.IMREAD_GRAYSCALE)
            if model_image is None:
                raise ValueError("Não foi possível abrir a imagem modelo.")

            cap = cv2.VideoCapture(video_path)
            if not cap.isOpened():
                raise ValueError("Não foi possível abrir o vídeo informado.")

            model_h, model_w = model_image.shape[:2]

            output_dir_path = Path(output_dir)
            anomalies_dir = output_dir_path / "frames_suspeitos"
            anomalies_dir.mkdir(exist_ok=True, parents=True)

            total_frames = 0
            suspect_frames = 0
            total_diff = 0.0
            max_diff = 0.0
            diff_samples = []
            saved_count = 0

            model_float = model_image.astype(np.float32)
            min_pixel_diff = 25

            while True:
                ok, frame = cap.read()
                if not ok:
                    break

                total_frames += 1
                gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
                gray = cv2.resize(gray, (model_w, model_h))

                diff = cv2.absdiff(gray, model_image)
                diff_ratio = (np.count_nonzero(diff > min_pixel_diff) / diff.size) * 100.0

                total_diff += diff_ratio
                max_diff = max(max_diff, diff_ratio)

                if diff_ratio > threshold_percent:
                    suspect_frames += 1
                    diff_samples.append(
                        {
                            "frame": total_frames,
                            "percentual_diferenca": round(float(diff_ratio), 2),
                        }
                    )

                    if saved_count < 12:
                        frame_path = anomalies_dir / f"frame_{total_frames:05d}.png"
                        cv2.imwrite(str(frame_path), frame)
                        saved_count += 1

            cap.release()

            average_diff = (total_diff / total_frames) if total_frames else 0.0

            report = {
                "modelo": model_path,
                "video": video_path,
                "limite_percentual": threshold_percent,
                "total_frames": total_frames,
                "frames_suspeitos": suspect_frames,
                "media_diferenca_percentual": round(float(average_diff), 2),
                "maior_diferenca_percentual": round(float(max_diff), 2),
                "frames_detectados": diff_samples,
                "pasta_resultados": str(output_dir_path),
                "frames_salvos": sorted(str(p.name) for p in anomalies_dir.glob("*.png")),
                "status": "OK" if suspect_frames == 0 else "ANOMALIA DETECTADA",
            }

            report_path = output_dir_path / "relatorio_comparacao.json"
            with open(report_path, "w", encoding="utf-8") as f:
                json.dump(report, f, ensure_ascii=False, indent=2)

            self.root.after(0, lambda: self._show_result(report, report_path))

        except Exception as exc:
            self.root.after(0, lambda: self._show_error(str(exc)))
        finally:
            self.root.after(0, lambda: self.run_button.config(state="normal"))

    def _show_result(self, report, report_path):
        summary = (
            f"Arquivo modelo: {report['modelo']}\n"
            f"Vídeo: {report['video']}\n\n"
            f"Total de frames analisados: {report['total_frames']}\n"
            f"Frames suspeitos: {report['frames_suspeitos']}\n"
            f"Média de diferença: {report['media_diferenca_percentual']}%\n"
            f"Maior diferença: {report['maior_diferenca_percentual']}%\n"
            f"Status: {report['status']}\n\n"
            f"Relatório salvo em: {report_path}\n"
            f"Frames salvos em: {report['pasta_resultados']}\\frames_suspeitos"
        )
        self._set_result(summary)

    def _show_error(self, error_message):
        self._set_result(f"Erro durante a análise:\n\n{error_message}")
        messagebox.showerror("Erro na comparação", error_message)


def main():
    root = tk.Tk()
    app = App(root)
    root.mainloop()


if __name__ == "__main__":
    main()

