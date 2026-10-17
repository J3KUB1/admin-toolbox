🛠️ Admin Toolbox
Admin Toolbox is an advanced, comprehensive administration tool written in PowerShell and wrapped in a Batch executable (.bat / .cmd). It features a Graphical User Interface (GUI) built on Windows Forms for managing, monitoring, diagnosing, and repairing the Windows operating system—both locally and remotely.

✨ Key Features
Dashboard: Quick overview of vital system metrics (computer name, OS build, CPU, RAM, uptime, disk health, and active network adapters) with an option to export a complete HTML status report.

Real-time Performance: Live graphs monitoring CPU, RAM, Disk activity, and Network usage.

Process & Service Management: Inspect running processes with options to terminate them (including entire process trees), and manage system services (start, stop, restart, change startup type).

Network & Diagnostics: Built-in network tools (Ping, Tracert, Nslookup, Port test), active connections viewer (netstat), ARP/route tables, Wi-Fi profile viewer, and quick network repairs (DNS flush, IP release/renew, Winsock & TCP/IP resets).

System Repair & Maintenance: Run system scans (SFC /scannow, DISM tools), schedule CHKDSK, clean temporary files (%TEMP%, Recycle Bin), reset Windows Update cache, create system restore points, and manage power options.

Security & Hardware Audit: Inspect Defender status, Windows Firewall, BitLocker, Secure Boot, and TPM settings. Detailed breakdown of hardware components, ACPI temperatures, and installed system drivers.

Disk Analysis & Cleanup: Identify large folders, massive files, and duplicates with safe options to move items to the Recycle Bin.

Remote Management (WinRM / CIM): Query remote processes and services, fetch remote system info, and perform remote power operations (restart, shutdown, logoff).

Custom Commands & Profiles: Save and run custom CMD or PowerShell scripts, organize them into categories, and import/export configuration profiles in JSON format.

Feature Search: Instantly locate UI tools and options using the built-in search bar (shortcut Ctrl + F).

Multi-language & Theme Support: Seamlessly toggle between Light/Dark themes and English/Polish languages.

🚀 How to Run
The tool is self-contained within a single .bat script.

Download the script file to your computer.

Double-click the file to open the launcher menu.

Select your desired option:

[1] Run as ADMINISTRATOR (UAC) (Recommended) – Unlocks full access to system repair and advanced administrative tools.

[2] Run as USER (non-UAC) – Restricted mode (functions requiring admin privileges will be disabled/greyed out).

⌨️ Useful Shortcuts
F5 – Refresh the active tab.

Ctrl + F – Focus the global feature search bar.

Enter – Execute selected search item.

Escape – Clear search or close dropdown.

🔒 Security & Data Storage
The application maintains a workspace in %APPDATA%\AdminToolbox to store settings (settings.json), custom commands (custom.json), and diagnostic logs (error.log).

Potentially destructive actions are protected by confirmation prompts before execution.


🛠️ Admin Toolbox 
Admin Toolbox to zaawansowane, kompleksowe narzędzie administracyjne stworzone w języku skryptowym PowerShell i wbudowane w skrypt wsadowy (Batch/CMD). Zapewnia graficzny interfejs użytkownika (GUI) oparty na Windows Forms do zarządzania, monitorowania, diagnostyki i naprawy systemu operacyjnego Windows – zarówno lokalnie, jak i zdalnie.

✨ Kluczowe Funkcje
Pulpit (Dashboard): Szybki podgląd najważniejszych parametrów komputera (nazwa, wersja systemu, procesor, RAM, czas działania, stan dysków oraz aktywne interfejsy sieciowe) z możliwością wygenerowania kompletnego raportu HTML.

Wydajność w czasie rzeczywistym: Monitorowanie wykorzystania CPU, RAM, dysku i sieci w formie płynnych, dynamicznych wykresów.

Zarządzanie procesami i usługami: Przeglądanie procesów z opcją ich natychmiastowego zamknięcia (w tym całego drzewa procesów), zarządzanie usługami systemowymi (start, stop, restart, zmiana typu uruchomienia).

Sieć i diagnostyka: Narzędzia sieciowe (Ping, Tracert, Nslookup, Test portu), podgląd aktywnych połączeń (netstat), tablic ARP/tras, zarządzanie profilami Wi-Fi oraz szybka naprawa sieci (czyszczenie DNS, odnawianie IP, reset Winsock / TCP/IP).

Naprawa i konserwacja systemu: Wbudowane skanowanie za pomocą SFC, narzędzia DISM, obsługa CHKDSK, czyszczenie plików tymczasowych (%TEMP%, Kosz), resetowanie usługi Windows Update, tworzenie punktów przywracania oraz zarządzanie zasilaniem.

Bezpieczeństwo i Sprzęt: Audyt stanu antywirusa (Microsoft Defender), zapory sieciowej, BitLockera, Secure Boot, TPM, a także szczegółowy podgląd podzespołów komputera, temperatur oraz zainstalowanych sterowników.

Analiza dysku i sprzątanie: Wyszukiwanie największych folderów, plików oraz duplikatów (z możliwością bezpiecznego przenoszenia do Kosza).

Zarządzanie zdalne (WinRM / CIM): Podgląd procesów, usług oraz wykonywanie operacji zasilania na zdalnych komputerach w sieci.

Własne polecenia i profile: Tworzenie własnych skryptów CMD/PowerShell, organizowanie ich w kategorie oraz eksport/import konfiguracji do formatu JSON.

Wyszukiwarka funkcji: Szybkie wyszukiwanie opcji w interfejsie za pomocą paska wyszukiwania (skrót Ctrl + F).

Wsparcie dla motywów (Jasny / Ciemny) oraz języków (PL / EN).

🚀 Jak uruchomić?
Skrypt jest spakowany jako plik .bat / .cmd.

Pobierz plik skryptu na swój komputer.

Kliknij na niego dwukrotnie.

Wybierz odpowiedni tryb w menu startowym:

[1] Uruchom jako ADMINISTRATOR (UAC) – zalecane, odblokowuje pełny dostęp do narzędzi systemowych, naprawy oraz zaawansowanych funkcji.

[2] Uruchom jako UŻYTKOWNIK (bez UAC) – tryb ograniczony (funkcje wymagające uprawnień administratora zostaną automatycznie zablokowane/wyszarzone).

⌨️ Przydatne skróty klawiszowe
F5 – Odświeżenie bieżącej zakładki.

Ctrl + F – Przejście do wyszukiwarki funkcji w interfejsie.

Enter – Zatwierdzenie wyszukiwania / uruchomienie wybranej opcji.

Escape – Wyczyszczenie wyszukiwania / zamknięcie podpowiedzi.

🔒 Bezpieczeństwo i Pliki Logów
Narzędzie automatycznie tworzy katalog roboczy w %APPDATA%\AdminToolbox, gdzie zapisywane są ustawienia użytkownika (settings.json), własne skrypty (custom.json) oraz dziennik błędów (error.log).

Wszelkie operacje wymagające podwyższonych uprawnień są zabezpieczone odpowiednimi monitami potwierdzającymi.
