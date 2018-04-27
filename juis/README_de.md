# Abfragen des JUIS (Java(?) Update Information Service) von AVM zur Suche nach neuer Firmware

**Zweck:**

Mit diesem Shell-Skript kann man über den AVM-Update-Service (JUIS) nach neuer Firmware suchen lassen.

Dank der Möglichkeit, fast jeden Aspekt bzw. Parameter einer solchen Abfrage nach eigenem Bedarf anzupassen, kann man damit für praktisch jedes beliebige FRITZ!Box-Modell nach neuer Firmware suchen lassen.

Trotzdem kann sich der Aufruf des Skripts im einfachsten Fall auf die Angabe des DNS-Namens oder der IP-Adresse einer existierenden (und von der LAN-Seite erreichbaren) FRITZ!Box im ersten Parameter beschränken und alle weiteren Angaben für die Abfrage beim Hersteller werden dann von dieser FRITZ!Box gelesen.

Damit ist es nach wie vor ganz einfach, regelmäßig bei AVM (dem Hersteller der FRITZ!Box) nach neuer Firmware zu suchen - auch von _außerhalb_ der FRITZ!Box und für den Fall, dass man aus (nachvollziehbaren) Sicherheitsbedenken lieber auf die automatische Suche und die automatische Installation neuer Firmware verzichten möchte ... es gab in der Vergangenheit da einige Vorkommnisse, bei denen offensichtlich die vorhandenen Einstellungen zum Update nicht wirklich berücksichtigt wurden von der Firmware.

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
-i, --ignore-cfgfile           - keine Konfigurationsdatei verwenden
```

Das Skript versucht, eine Konfigurationsdatei zur Anpassung an die lokalen Gegebenheiten zu verwenden, dazu wird nach einer Datei mit dem (Aufruf-)Namen des Skripts und der Erweiterung ```cfg``` in dem Verzeichnis gesucht, in welchem das Skript selbst enthalten ist. Diese Datei wird dann _eingefügt_ und kann beliebigen Shell-Code enthalten - **man sollte also sehr genau die hiermit zum Ausdruck gebrachte Warnung beachten, dass es sich zu einem schweren Sicherheitsproblem auswachsen kann, wenn irgendjemand diese Datei ohne Kenntnis des Benutzers ändern kann**.

Will man eine Konfigurationsdatei mit einem anderen Namen verwenden, kann deren Name über die Umgebungsvariable ```JUIS_CHECK_CFG``` festgelegt werden. Soll gar keine Konfigurationsdatei benutzt werden, kann man die Option ```--ignore-cfgfile``` (oder ```-i```) angeben - dann muß man aber auf irgendeinem anderen Weg dafür sorgen, daß die Variable ```Box``` einen passenden Wert hat, wenn nicht alle notwendigen Parameter explizit gesetzt wurden und ein Auslesen weiterer Werte aus einer FRITZ!Box erforderlich ist.

Wird keine Konfigurationsdatei (mit dem automatisch gebildeten Namen) gefunden und wurde ihre Verarbeitung nicht über die o.a. Option unterdrückt, wird folgener Inhalt angenommen:

```shell
Box=$1
shift
```

\- damit wird also als erster und einziger Parameter die Angabe des DNS-Namens oder der IP-Adresse der FRITZ!Box erwartet, von der weitere Einstellungen zu lesen wären. Gleichzeitig dürfen aber auf der Kommandozeile noch weitere Angaben folgen, die dann ihrerseits einen der im Folgenden beschriebenen Parameter festlegen (solange bei der Beschreibung der Variablen nichts anderes steht).

Egal, auf welchem Weg man jetzt die notwendigen Parameter bereitstellt (ob bereits beim Aufruf der Skript-Datei über das Shell-Environment oder über entsprechende Paare aus Namen und Werten (verbunden durch ein Gleichheitszeichen) auf der Kommandozeile oder über die Anweisungen in einer Konfigurationsdatei), am Ende braucht es für die Abfrage die folgenden Werte:

| Name | | Bedeutung/Inhalt |
| :---: | :---: | :--- |
| Version | | die Version der Firmware, die als Basis für die Suche nach einer **neuen** Version benutzt werden soll - das ist die kombinierte Versionsnummer aus den folgenden Variablen und ihr Wert _überstimmt_ mit jedem dort enthaltenen Einzelwert alle anderen Angaben, unabhängig von ihrer Quelle: |
| | Major | die modellspezifische Firmware-Version ... üblicherweise ist das der Wert von ```HW``` (also der ```HWRevision``` der Box) minus 72, wie man mir mal irgendwo geschrieben hat |
| | Minor | die _Hauptversion_ des FRITZ!OS |
| | Patch | die _Unterversion_ des FRITZ!OS |
| | Buildnumber | eine immer weiter ansteigende Zahl, die vermutlich eine fortlaufende Nummerierung für die komplettierten Durchläufe zum Erstellen einer Firmware bei AVM darstellt und über alle Modelle _hochgezählt_ wird; in älteren Firmware-Versionen (und in der ```jason_boxinfo.xml```) lief das noch unter dem Namen ```Revision``` |
| Serial | | die _Seriennummer_ der FRITZ!Box, üblicherweise ist das aber in Wirklichkeit der Wert von ```maca``` (also der MAC-Adresse auf dem LAN-Interface) und nicht der Wert von ```SerialNumber``` aus dem FRITZ!Box-Environment im TFFS |
| Name | | der Produktname der FRITZ!Box (```CONFIG_PRODUKT```), kann auch Leerzeichen enthalten |
| HW | | der Wert von ```HWRevision``` aus dem FRITZ!Box-Environment im TFFS |
| OEM | | der Wert für das _Branding_, hiermit wird bei Boxen, die speziell für bestimmte ISPs produziert wurden, eine providerspezifische Konfiguration eingestellt; bei den Geräten, die sich direkt als *AVM FRITZ!Box* zu erkennen geben, steht dort ```avm``` für Geräte mit deutscher Firmware und ```avme``` für solche, die eine Version der Firmware für internationale Verwendung installiert haben (oder hatten) |
| Lang | | die in der Firmware eingestellte Sprache, wenn die Firmware mehrere Sprachversionen unterstützt oder einfach ```de``` für die deutsche Version |
| Annex | | das vom zuletzt verwendeten DSL-Anschluss genutzte Schema für die Belegung der Frequenzen (bei DSL-Boxen) oder ```Kabel``` bei den DOCSIS-Boxen |
| Country | | der in der Box eingestellte Ländercode (nach ITU-Empfehlung - E.164) |
| Flag | | eine durch Kommata getrennte Liste von _Flags_, die bei der Abfrage des AVM-Servers zu verwenden sind - eine erfolgreiche Abfrage für die FRITZ!Box 6590 braucht hier z.B. (derzeitiger Stand, kann sich bei AVM jederzeit ändern) die Angabe von ```cable_retail```, damit man eine sinnvolle Antwort erhält |
| | | |
| Public | | ```1```, um nur nach offziellen Versionen zu suchen oder ```0```, um auch die sogenannten _Inhouse_-Versionen (zumindest bei einigen dieser Firmware-Einträge steht dann ein '_Inhouse_' oder '_Inhaus_' auch in der Beschreibung der Version in der SOAP-Antwort, daher habe ich diese Benennung irgendwann mal übernommen) zu finden, für die AVM aber natürlich noch viel weniger Support leistet als für die offiziellen Labor-Versionen (und für die gibt es schon keinen Support) - dieser Parameter eignet sich auch nicht für den Einstieg in eine Labor-Reihe, der muss immer noch über die manuelle Installation der ersten Labor-Version erfolgen und erst danach kann man dann (vermutlich auf der Basis von ```Buildnumber```) auch weitere Labor-Versionen über die Abfrage bei AVM finden
| | | |
| Nonce | | dieser Parameter ist komplett optional, sein Fehlen führt auch nicht zur Abfrage bei der FRITZ!Box und der Wert (es muss sich um die Base64-Darstellung einer Folge von 16 Bytes mit (möglichst) zufälligen Daten handeln) wird vor seiner Verwendung nicht auf seine Gültigkeit geprüft - er muss nur dann angegeben werden, wenn der Aufrufer die Antwort des AVM-Servers speichern lassen will (mit der Option ```-s```) und dann seinerseits die Gültigkeit der Signatur in der SOAP-Response von AVM prüfen möchte
| | | |
| Box | | dieser Wert kann nicht durch die Angabe als Name/Wert-Paar auf der Kommandozeile festgelegt werden, aber es ist möglich, ihn bereits vor dem Start über das Shell-Environment zu setzen oder eben über eine Zuweisung in einer Konfigurationsdatei; aber sollten nach der Verarbeitung der Name/Wert-Paare von der Kommandozeile und nach dem Ausführen der Anweisungen in einer Konfigurationsdatei noch Einstellungen fehlen, die für den SOAP-Request benötigt werden, so muss diese Variable den DNS-Namen oder die IP-Adresse der FRITZ!Box enthalten, von der die fehlenden Angaben gelesen werden sollen (aus der Datei ```juis_boxinfo.xml``` oder, wenn diese Datei in älterer Firmware nicht existieren sollte, aus der Datei ```jason_boxinfo.xml```) |

Die Werte für ```Major```, ```Minor```, ```Patch``` und ```Buildnumber``` können auch nicht über Name/Wert-Paare auf der Kommandozeile gesetzt werden, nur vor dem Aufruf über das Environment oder über Zuweisungen in einer Konfigurationsdatei. Will man tatsächlich die Versionsnummer beim Aufruf direkt von der Kommandozeile aus angeben, muss man dafür die _kombinierte_ Versionsnummer als ```Version``` verwenden, die sich aus ```Major```, ```Minor``` und ```Patch``` - jeweils mit einem Punkt getrennt - zusammensetzt, denen dann - durch einen Bindestrich (oder auch ein Minuszeichen, ganz wie man will) getrennt - noch die ```Buildnumber``` folgt.

Sollten jedenfalls am Ende noch irgendwelche Angaben fehlen (die Option ```--debug``` kann auch benutzt werden, um die Variablenzuweisungen zu protokollieren), muss die Variable ```Box``` einen Wert enthalten, der die Abfrage einer vorhandenen FRITZ!Box ermöglicht.

Für jede benötigte Einstellung kann man auch den Wert ```detect``` angeben, das hat denselben Effekt wie das Fehlen dieser Einstellung und führt zum Versuch, den Wert aus der Box zu lesen. Will man einen Wert nicht angeben und gleichzeitig verhindern, dass dieser aus dem Gerät gelesen wird, kann man ```empty``` angeben - das Ergebnis ist dann ein leerer Wert. Als drittes _Schlüsselwort_ im Wert einer Variablen kann ```fixed``` angegeben werden, dem dann - durch einen Doppelpunkt getrennt - der eigentliche Wert folgt. Das ist zwar dasselbe wie die direkte Angabe des Wertes, aber wenn dieser Wert selbst eines der Schlüsselworte wäre (also ```detect``` oder ```empty```), dann braucht man auch mal das ```fixed:``` als Präfix.

Wenn man einen Wert angeben will (oder muss), der seinerseits ein Leerzeichen (oder irgendein anderes Zeichen aus der IFS-Variablen) enthält, muss man beachten, dass später im Skript die Zuweisungen auch noch einmal über ein ```eval```-Kommando getestet werden, daher muß man diese Zeichen passend maskieren, wenn man sie in einer Konfigurationsdatei verwenden will. Um z.B. den Produktnamen mit einem Leerzeichen zu setzen, müsste man in der Konfigurationsdatei die Anweisung:

```shell
Name="FRITZ!Box\\ 7490"
```

verwenden, um am Ende ein Leerzeichen im Wert für die Abfrage bei AVM zu erhalten.

Der Rückgabewert des Skripts (der 'exit code') kann verwendet werden, um Informationen über das Ergebnis zu erhalten - dabei werden die folgenden Werte verwendet:

| Wert | Bedeutung |
| :---: | :--- |
| 0 | neue Firmware gefunden, die URL zum Download wurde nach STDOUT geschrieben |
| 1 | Fehler beim Aufruf des Skripts, z.B. fehlender Wert für die ```Box```-Variable, ungültige Parameter beim Aufruf, fehlende Programme, usw. |
| 2 | keine neue Firmware gefunden, aber die Abfrage bei AVM war erfolgreich |
| 3 | unvollständige Parameter, i.d.R. auch das Ergebnis einer nicht erreichbaren FRITZ!Box beim Versuch, fehlende Werte von dort zu lesen |
| 4 | die Abfrage bei AVM war falsch, das kann an fehlenden oder falschen Parametern liegen und ist am Ende nur eine Schlussfolgerung aus der Tatsache, dass es gar keine Antwort vom AVM-Server innerhalb der Timeout-Zeitspanne gab (der könnte aber auch ganz simpel mal ausgefallen sein), die Antwort nicht von ```200 OK``` als Status-Code begleitet ist oder in der Antwort nicht die erwarteten Felder - das wären ```Found``` und ```DownloadURL``` im XML-Namespace ```ns3``` (```http://juis.avm.de/response```) - vorhanden sind |

---
Wer eine Lizenz für MS Office hat, kann auch die Version in Excel von @Chatty benutzen: <https://github.com/TheChatty/JUISinExcel>
