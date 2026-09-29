@echo off
python -m pip install --upgrade pip
pip install -r requirements.txt
pyinstaller --onefile --windowed --name "MonitorCabo" app.py

echo.
echo Executavel gerado em dist\MonitorCabo.exe
pause
