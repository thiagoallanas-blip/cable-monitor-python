# Monitor de Cabo - Comparação de imagem e vídeo

Este projeto oferece uma interface simples em Python para:

- selecionar uma foto modelo
- selecionar um vídeo para comparação
- analisar frames do vídeo contra a imagem de referência
- identificar anomalias por diferença de pixels
- gerar um relatório JSON com os resultados
- salvar imagens de frames detectados como suspeitos

## Requisitos

- Python 3.10+
- OpenCV
- NumPy
- Pillow

## Instalação

```bash
python -m venv .venv
source .venv/bin/activate  # Windows: .venv\Scripts\activate
pip install -r requirements.txt
```

## Execução

```bash
python app.py
```

## Executável Windows

No Windows, você pode gerar um `.exe` com PyInstaller:

```bat
pip install pyinstaller
pyinstaller --onefile --windowed --name "MonitorCabo" app.py
```

O executável ficará em `dist\MonitorCabo.exe`.

## Como usar

1. Clique em **Selecionar foto modelo**.
2. Clique em **Selecionar vídeo**.
3. Ajuste o limite de tolerância (ex.: 5% ou 10%).
4. Clique em **Iniciar comparação**.
5. O programa exibirá:
   - número total de frames analisados
   - frames com diferença detectada
   - média de diferença
   - pior caso
   - caminho do relatório JSON salvo

## Estrutura

- `app.py` — interface e processamento principal
- `requirements.txt` — dependências
- `build_exe.bat` — helper para gerar executável no Windows
- `README.md` — documentação

