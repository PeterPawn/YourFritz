# Abfragen des JUIS (Java(?) Update Information Service) von AVM zur Suche nach neuer Firmware

**Zweck:**

Mit diesem Shell-Skript kann man über den AVM-Update-Service (JUIS) nach neuer Firmware suchen lassen.

Dank der Möglichkeit, fast jeden Aspekt bzw. Parameter einer solchen Abfrage nach eigenem Bedarf anzupassen, kann man damit für praktisch jedes beliebige FRITZ!Box-Modell nach neuer Firmware suchen lassen.

Trotzdem kann sich der Aufruf des Skripts im einfachsten Fall auf die Angabe des DNS-Namens oder der IP-Adresse einer existierenden (und von der LAN-Seite erreichbaren) FRITZ!Box im ersten Parameter beschränken und alle weiteren Angaben für die Abfrage beim Hersteller werden dann von dieser FRITZ!Box gelesen.

Damit ist es nach wie vor ganz einfach, regelmäßig bei AVM (dem Hersteller der FRITZ!Box) nach neuer Firmware zu suchen - auch von _außerhalb_ der FRITZ!Box und für den Fall, dass man aus (nachvollziehbaren) Sicherheitsbedenken lieber auf die automatische Suche und die automatische Installation neuer Firmware verzichten möchte.

**Aufruf:**

```text
    juis_check [ Optionen ] [ -- ] [ optionale Parameter ]
```

Verfügbare Optionen sind:

```text
-d, --debug                    - Debug-Ausgaben auf STDERR; muss die erste Option sein
-h, --help                     - Anzeige dieser Hilfe-Information (muss die erste Option sein)
-V, --version                  - (ausschließliche) Anzeige der Versionsinformation
-n, --no-respawn               - nicht neu starten mit der 'bash' als Shell
-s, --save-response <filename> - die Antwort vom AVM-Server wird in <filename> gespeichert
-a, --show-response            - die Antwort vom AVM-Server wird nach STDERR ausgegeben
-i, --ignore-cfgfile           - keine Konfigurationsdatei verwenden
-c, --current                  - aktuelle Version ermitteln ('Patch' - s.u. - wird dekrementiert)
-l, --local                    - die Daten der Box verwenden, auf der das Skript läuft
-p, --print-version            - die Versionsnummer der gefundenen Firmware zusätzlich ausgeben auf STDOUT
-r, --use-real-serial          - die echte Seriennummer (maca) der Box senden
```

Das Skript versucht, eine Konfigurationsdatei zur Anpassung an die lokalen Gegebenheiten zu verwenden, dazu wird nach einer Datei mit dem (Aufruf-)Namen des Skripts und der Erweiterung ```cfg``` in dem Verzeichnis gesucht, in welchem das Skript selbst enthalten ist. Diese Datei wird dann _eingefügt_ und kann beliebigen Shell-Code enthalten - **man sollte also sehr genau die hiermit zum Ausdruck gebrachte Warnung beachten, dass es sich zu einem schweren Sicherheitsproblem auswachsen kann, wenn irgendjemand diese Datei ohne Kenntnis des Benutzers ändern kann**.

Will man eine Konfigurationsdatei mit einem anderen Namen verwenden, kann deren Name über die Umgebungsvariable ```JUIS_CHECK_CFG``` festgelegt werden. Soll gar keine Konfigurationsdatei benutzt werden, kann man die Option ```--ignore-cfgfile``` (oder ```-i```) angeben - dann muß man aber auf irgendeinem anderen Weg dafür sorgen, daß die Variable ```Box``` einen passenden Wert hat, wenn nicht alle notwendigen Parameter explizit gesetzt wurden und ein Auslesen weiterer Werte aus einer FRITZ!Box erforderlich ist.

Wird keine Konfigurationsdatei (mit dem automatisch gebildeten Namen) gefunden und wurde ihre Verarbeitung nicht über die o.a. Option unterdrückt, wird folgener Inhalt angenommen:

```shell
Box=$1
shift
```

\- damit wird also als erster und einziger Parameter die Angabe des DNS-Namens oder der IP-Adresse der FRITZ!Box erwartet, von der weitere Einstellungen zu lesen wären. Gleichzeitig dürfen aber auf der Kommandozeile noch weitere Angaben folgen, die dann ihrerseits einen der weiter unten beschriebenen Parameter festlegen (solange bei der Beschreibung der Variablen nichts anderes steht).

Bei Angabe der Option ```--show-response```, wird die SOAP-Response aus der AVM-Antwort extrahiert
(also die HTTP-Header aus der Antwort entfernt) und das Ergebnis nach STDERR ausgegeben. Um
diese Anzeige übersichtlicher zu gestalten, wird dabei ein Programm zur Formatierung der (im
Original einzeiligen) Ausgabe verwendet, sofern ein solches gefunden wird. Standardmäßig wird
dabei nach ```xmllint``` aus dem ```libxml2```-Projekt (<http://xmlsoft.org/index.html>) gesucht, dieser
Name kann mit der Environment-Variablen ```XML_LINTER``` überschrieben werden. Wird kein passendes
Programm gefunden, erfolgt die Ausgabe der Daten 1:1 so, wie sie von AVM gesendet wurden.

Egal, auf welchem Weg man jetzt die notwendigen Parameter bereitstellt (ob bereits beim Aufruf der Skript-Datei über das Shell-Environment oder über entsprechende Paare aus Namen und Werten (verbunden durch ein Gleichheitszeichen) auf der Kommandozeile oder über die Anweisungen in einer Konfigurationsdatei), am Ende braucht es für die Abfrage die folgenden Werte:

| Name | | Bedeutung/Inhalt |
| :---: | :---: | :--- |
| Version | | die Version der Firmware, die als Basis für die Suche nach einer **neuen** Version benutzt werden soll - das ist die kombinierte Versionsnummer aus den folgenden Variablen und ihr Wert _überstimmt_ mit jedem dort enthaltenen Einzelwert alle anderen Angaben, unabhängig von ihrer Quelle: |
| | Major | die modellspezifische Firmware-Version |
| | Minor | die _Hauptversion_ des FRITZ!OS |
| | Patch | die _Unterversion_ des FRITZ!OS |
| | Buildnumber | eine immer weiter ansteigende Zahl, die vermutlich eine fortlaufende Nummerierung für die komplettierten Durchläufe zum Erstellen einer Firmware bei AVM darstellt und über alle Modelle _hochgezählt_ wird; in älteren Firmware-Versionen (und in der ```jason_boxinfo.xml```) lief das noch unter dem Namen ```Revision``` |
| Serial | | die _Seriennummer_ der FRITZ!Box, üblicherweise ist das aber in Wirklichkeit der Wert von ```maca``` (also der MAC-Adresse auf dem LAN-Interface) und nicht der Wert von ```SerialNumber``` aus dem FRITZ!Box-Environment im TFFS<br>**Anstatt des von der FRITZ!Box gelesenen Wertes wird hier (bei fehlender Angabe) nur die Kombination aus den ersten drei Bytes (der OUI), gefolgt von einem zufälligen Wert, der definitiv nicht der tatsächlichen MAC-Adresse entspricht, verwendet. Wer den echten Wert verwenden möchte, kann das durch Angabe der Option ```-r``` erreichen - die Daten werden dann aber ohne weitere Nachfrage an den Hersteller gesendet.** |
| Name | | der Produktname der FRITZ!Box (```CONFIG_PRODUKT```), kann auch Leerzeichen enthalten |
| HW | | der Wert von ```HWRevision``` aus dem FRITZ!Box-Environment im TFFS |
| OEM | | der Wert für das _Branding_, hiermit wird bei Boxen, die speziell für bestimmte ISPs produziert wurden, eine providerspezifische Konfiguration eingestellt; bei den Geräten, die sich direkt als *AVM FRITZ!Box* zu erkennen geben, steht dort ```avm``` für Geräte mit deutscher Firmware und ```avme``` für solche, die eine Version der Firmware für internationale Verwendung installiert haben (oder hatten) |
| Lang | | die in der Firmware eingestellte Sprache, wenn die Firmware mehrere Sprachversionen unterstützt oder einfach ```de``` für die deutsche Version |
| Annex | | das vom zuletzt verwendeten DSL-Anschluss genutzte Schema für die Belegung der Frequenzen (bei DSL-Boxen) oder ```Kabel``` bei den DOCSIS-Boxen |
| Country | | der in der Box eingestellte Ländercode (nach ITU-Empfehlung - E.164) |
| Flag | | eine durch Kommata getrennte Liste von _Flags_, die bei der Abfrage des AVM-Servers zu verwenden sind - eine erfolgreiche Abfrage für die FRITZ!Box 6590 braucht hier z.B. (derzeitiger Stand, kann sich bei AVM jederzeit ändern) die Angabe von ```cable_retail```, damit man eine sinnvolle Antwort erhält |
| | | |
| Buildtype | | dieser Parameter wird von AVM benutzt, um die verschiedenen Entwicklungsreihen der Firmware (Release, Labor, Inhouse, spez. Beta-Versionen für einzelne Änderungen, etc.) voneinander zu unterscheiden. Eigentlich besteht sein Wert aus einer ein- bis fünfstelligen Dezimalzahl und so kann dieser Wert hier (sofern man ihn kennt) auch direkt angegeben werden. Fehlt er, wird er üblicherweise von einer vorhandenen FRITZ!Box gelesen (s.u. für die Beschreibung von ```Box```). Wird er explizit nicht angegeben (Wert ```empty```), wird ```1``` als Standard verwendet.<br />Um diesen Parameter auch ohne Kenntnis der passenden numerischen Angaben benutzbar zu machen, gibt es ein paar vordefinierte Namen für diese Firmware-Serien. Ein angegebener Wert wird zuerst in Großschreibweise überführt (es spielt also keine Rolle, wie der Wert geschrieben wurde, solange die Abfolge der Buchstaben paßt) und das Ergebnis mit den Bezeichnungen aus der unten stehenden Liste verglichen. Handelt es sich beim angegebene Wert um einen dieser Bezeichner, wird der ihm zugeordnete numerische Wert für die Anfrage bei AVM verwendet. Da es für einige Werte mehrere (gebräuchliche) Namen gibt, sind einige Werte auch mehrfach in der Liste vorhanden.<br />RELEASE=1<br />LABOR=1001<br />BETA=1001<br />LABBETA=1001<br />PLUS=1007<br />LABPLUS=1007<br />INHOUSE=1000<br />INHAUS=1000<br />PHONE=1004<br />LABPHONE=1004 |
| | | |
| Public | | ```1```, um nur nach offziellen Versionen zu suchen oder ```0```, um auch die sogenannten _Inhouse_-Versionen zu finden<br />**Das Verwenden dieses Parameters wird ab Version 0.5 nicht mehr empfohlen, stattdessen sollte der Parameter 'Buildtype' (s.o.) genutzt werden.**<br />Wird er weiterhin genutzt, wird für ```Public=0``` der Wert ```1000``` und für ```Public=1``` der Wert ```1001``` als ```Buildtype``` verwendet. Eine gleichzeitige Benutzung von ```Public``` und ```Buildtype``` ist nicht erlaubt. |
| | | |
| Nonce | | dieser Parameter ist komplett optional, sein Fehlen führt auch nicht zur Abfrage bei der FRITZ!Box und der Wert (es muss sich um die Base64-Darstellung einer Folge von 16 Bytes mit (möglichst) zufälligen Daten handeln) wird vor seiner Verwendung nicht auf seine Gültigkeit geprüft - er muss nur dann angegeben werden, wenn der Aufrufer die Antwort des AVM-Servers speichern lassen will (mit der Option ```-s```) und dann seinerseits die Gültigkeit der Signatur in der SOAP-Response von AVM prüfen möchte
| | | |
| Box | | dieser Wert kann nicht durch die Angabe als Name/Wert-Paar auf der Kommandozeile festgelegt werden, aber es ist möglich, ihn bereits vor dem Start über das Shell-Environment zu setzen oder eben über eine Zuweisung in einer Konfigurationsdatei; aber sollten nach der Verarbeitung der Name/Wert-Paare von der Kommandozeile und nach dem Ausführen der Anweisungen in einer Konfigurationsdatei noch Einstellungen fehlen, die für den SOAP-Request benötigt werden, so muss diese Variable den DNS-Namen oder die IP-Adresse der FRITZ!Box enthalten, von der die fehlenden Angaben gelesen werden sollen (aus der Datei ```juis_boxinfo.xml``` oder, wenn diese Datei in älterer Firmware nicht existieren sollte, aus der Datei ```jason_boxinfo.xml```) |

Die Werte für ```Major```, ```Minor```, ```Patch``` und ```Buildnumber``` können auch nicht über Name/Wert-Paare auf der Kommandozeile gesetzt werden, nur vor dem Aufruf über das Environment oder über Zuweisungen in einer Konfigurationsdatei. Will man tatsächlich die Versionsnummer beim Aufruf direkt von der Kommandozeile aus angeben, muss man dafür die _kombinierte_ Versionsnummer als ```Version``` verwenden, die sich aus ```Major```, ```Minor``` und ```Patch``` - jeweils mit einem Punkt getrennt - zusammensetzt, denen dann - durch einen Bindestrich (oder auch ein Minuszeichen, ganz wie man will) getrennt - noch die ```Buildnumber``` folgt.

Sollten jedenfalls am Ende noch irgendwelche Angaben fehlen (die Option ```--debug``` kann auch benutzt werden, um die Variablenzuweisungen zu protokollieren), muss die Variable ```Box``` einen Wert enthalten, der die Abfrage einer vorhandenen FRITZ!Box ermöglicht.

Für jede benötigte Einstellung kann man auch den Wert ```detect``` angeben, das hat denselben Effekt wie das Fehlen dieser Einstellung und führt zum Versuch, den Wert aus der Box zu lesen. Will man einen Wert nicht angeben und gleichzeitig verhindern, dass dieser aus dem Gerät gelesen wird, kann man ```empty``` angeben - das Ergebnis ist dann ein leerer Wert. Als drittes _Schlüsselwort_ im Wert einer Variablen kann ```fixed``` angegeben werden, dem dann - durch einen Doppelpunkt getrennt - der eigentliche Wert folgt. Das ist zwar dasselbe wie die direkte Angabe des Wertes, aber wenn dieser Wert selbst eines der Schlüsselworte wäre (also ```detect``` oder ```empty```), dann braucht man auch mal das ```fixed:``` als Präfix.

Wenn man einen Wert angeben will (oder muss), der seinerseits ein Leerzeichen (oder irgendeinanderes Zeichen aus der IFS-Variablen) enthält, muss man diesen Wert beim Aufruf passend in Anführungszeichen setzen. Alternativ kann anstelle eines normalen Leerzeichens auch das Unicode-Zeichen für ```ZERO WIDTH SPACE``` (U+200B) benutzt werden, diese Zeichen werden vor der Verwendung im SOAP-Request durch normale ```SPACE```-Kodierungen (U+0020) ersetzt. Verwendet man Anführungszeichen, kann man diese nach eigenem Ermessen entweder um die gesamte Angabe von ```Parameter=Wert``` setzen oder auch nur um ```Wert```; die Angaben:

```'Name=FRITZ!Box 7490 (UI)'``` und
```Name='FRITZ!Box 7490 (UI)'```

sind also vom Ergebnis her identisch. Doppelte Anführungszeichen sollte man hier nur nutzen, wenn ihre Verwendung einen speziellen Grund hat, z.B. Shell-Variablen in der Angabe, die beim Aufruf substituiert werden sollen.
---
Der Rückgabewert des Skripts (der 'exit code') kann verwendet werden, um Informationen über das Ergebnis zu erhalten - dabei werden die folgenden Werte verwendet:

| Wert | Bedeutung |
| :---: | :--- |
| 0 | neue Firmware gefunden, die URL zum Download wurde nach STDOUT geschrieben |
| 1 | Fehler beim Aufruf des Skripts, z.B. fehlender Wert für die ```Box```-Variable, ungültige Parameter beim Aufruf, fehlende Programme, usw. |
| 2 | keine neue Firmware gefunden, aber die Abfrage bei AVM war erfolgreich |
| 3 | unvollständige Parameter, i.d.R. auch das Ergebnis einer nicht erreichbaren FRITZ!Box beim Versuch, fehlende Werte von dort zu lesen |
| 4 | die Abfrage bei AVM war falsch, das kann an fehlenden oder falschen Parametern liegen und ist am Ende nur eine Schlussfolgerung aus der Tatsache, dass es gar keine Antwort vom AVM-Server innerhalb der Timeout-Zeitspanne gab (der könnte aber auch ganz simpel mal ausgefallen sein), die Antwort nicht von ```200 OK``` als Status-Code begleitet ist oder in der Antwort nicht die erwarteten Felder - das wären ```Found``` und ```DownloadURL``` im XML-Namespace ```ns3``` (```http://juis.avm.de/response```) - vorhanden sind |
| 5 | Fehler bei der Netzwerk-Kommunikation (Host nicht gefunden, Timeout, etc.) |
---
Wer eine Lizenz für MS Office hat, kann auch die Version in Excel von @Chatty benutzen: <https://github.com/TheChatty/JUISinExcel>

Mittlerweile gibt es auch eine Windows-Version mit graphischer Oberfläche (die kann dann u.a. auch Firmware für Zubehör bei AVM suchen), nähere Informationen kann man hier nachlesen: <https://www.ip-phone-forum.de/threads/update-check-juischeck-f%C3%BCr-windows.301927/post-2310055>
