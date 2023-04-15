Fido: Un script PowerShell per scaricare gli ISO di Microsoft Windows e di UEFI Shell
============================================================================

[![Licenza](https://img.shields.io/badge/licenza-GPLv3-blue.svg?style=flat-square)](https://www.gnu.org/licenses/gpl-3.0.en.html)
[![Statistiche GitHub](https://img.shields.io/github/downloads/pbatard/Fido/total.svg?style=flat-square&label=scaricamenti)](https://github.com/pbatard/Fido/releases)

Descrizione
-----------

Fido è un script PowerShell che è progettato per essere utilizzato con il tool [Rufus](https://github.com/pbatard/rufus), ma 
che può essere anche utilizzato indipendentemente, il quale scopo è di automatizzare l'accesso ai link ufficiali per
scaricare Retail ISO di Microsoft Windows e fornire un accesso conveniente alle [immagini avviabili UEFI Shell](https://github.com/pbatard/UEFI-Shell).

Questo script esiste perché, mentre Microsoft fa i link per scaricare retail ISO libero e pubblicamente disponibile
(almeno per Windows 8 a Windows 11), fino al gli rilasci recenti, gli maggior parte di questi link erano solo disponibile
dopo costringendo gli utenti a saltare attraverso un sacco di cerchi di fuoco che ha creato un controproducente, se no
ostile, esperienza del consumatore, che ha detratto da cosa persone voligono veramente (accesso dirreto a gli link per 
scaricare gli ISO).
<!---
The idiom "jumping through hoops" is, as all idioms, difficult to translate, so the "unwarranted" was removed and "hoops 
of fire" was added.
--->
Il raggione perche qualchuno vorrei scaricare gli __retail__ ISO Windows in contrapposizione a generare gli ISO con
il "Media Creation Tool" (MCT) di Microsoft, è perche usando gli ufficiale retail ISO è, per ora, l'unica metodo
per fare sicuro che il contento di il tuo OS non si ha cambiatio. Perche c'è solo un singolo "master" per ciascuno di 
essi, gli retail ISO da Microsoft sono l'unici che puoi prendere un ufficiale SHA-1 (da MSDN, se c'hai accesso, o
da altri siti [tipo questa](https://msdn.rg-adguard.net/public.php)) che ti permette di essere 100% siciro che il ISO
che stai usando non e corrotto è e sicuro per usare.

Questo garanzie che il contento che __TU__ stai usando a instalare sul tuo OS, che è criticale per la tua sicurezza per
assicurarsi prima, se tu hai anche un piccolo preoccupazione per la tua sicurezza, che è esatto, bit per bit, quello che 
Microsoft ha pubblicato.

D'altra parte, indipendentemente dal modo del Media Creation Tool di Microsoft produce contento, perche no due
ISO generato da il MCT sono esatto (perche il MCT sempre si rigenera il contento del'ISO in tempo reale) per ora, 
e impossibile a fare sicuro con assoluta certezza se qualunque ISO generato da il MCT è sicuro per usare.
Soprattutto, al contrario il caso per gli retail ISO, è impossible per vedere se un ISO generato da MCT è stato
corrotto dopo generatione.

Da qui la necessità per fornire le utenti un modo per accessare ufficiale retail ISO piu facile é meno restrittivo...

Licensa
-------

[Licensa GNU generale publico versione 3.0](https://www.gnu.org/licenses/gpl-3.0) [non c'e un traduzione in Italiano] o più recente.

Come funziona
------------

Questa script practicalmente esegue le stesse operazioni che uno magari esegue quando andando il seguente link 
(se, in il caso di Windows 10, hai cambiato il tuo stringa del browser `User-Agent`, perche le web server di 
Microsoft vedono che tu stai usando una versiona di Windows che è lo stesso di quello che vuoi scaricare,
loro magari ti reindirizzare __via__ la paggina dove puoi ottenere un link per scaricare ISO direttamente):

https://www.microsoft.com/it-it/software-download

Dopo aver controllato accesso basico al sito per scaricare software da Microsoft il script prima interroga il API web 
da le server Microsoft, per richiedere la seleziona lingua disponibile per la versione di Windows selezionato, é poi
richiedere gli link download, per tutti architetture disponibile per quella lingua + versione.

Requisiti
------------

Windows 8 o più recente con PowerShell. Windows 7 __non è__ supportato.

Modo "Commandline"
----------------

Fido supporta il modo Commandline mentre, quando una di questi opzioni si è messo, un GUI non e istanziato
e puoi invece generare il link per scaricare l'ISO da un terminale o script PowerShell.

Gli optioni sono:

- `Win`: Specificare la versiona Windows (tipo _"Windows 10"_). La versiona abbreviato dovrebbe anche funzionare (tipo `-Win 10`)
   finché è abbastanza unico. Se questa optione non è specificato, la più recente versiona di Windows e automaticamente selezionato.
   Puoi ottenere una lista di versione supportato specificando `-Win List`.
   
- `Rel`: Specificare il rilascio Windows (tipo _"21H1"_). Se questa optione non è specificato, la più recente rilascio per 
   la versione di Windows scelto e automaticamente selezionato. Puoi anche usare `-Rel Latest` per forzare la più recente 
   versiona per essere usato. Puoi ottenere una lista di versione supportato specificando `-Rel List`.
   
- `Ed`: Specificare la editione Windows (tipo _"Pro/Home"_).  La versiona abbreviato dovrebbe anche funzionare (tipo `-Ed Pro`)
   finché è abbastanza unico. Se questa optione non è specificato, la più recente versiona di Windows e automaticamente
   selezionato. Puoi ottenere una lista di versione supportato specificando `-Ed List`.
   
- `Lang`: Specificare la lingua Windows (tipo _"Arabic"_). La versiona abbreviato o parta di una lingua (tipo `-Lang Int` per
   `English International`) dovrebbe anche funzionare finché è abbastanza unico. Se questa optione non è specificato, il script
   tenta a selezionare la stessa lingua dell sistema. Puoi ottenere una lista di lingue supportato specificando `-Lang List`.
   
- `Arch`: Specificare la architetture Windows (tipo _"x64"_). Se questa optione non è specificato, il script tenta a selezionare
   la stessa architetture dell sistema
   
- `GetUrl`: Di default, il script tenta a iniziare il scaricamento automaticamente. Ma, quando usando `-GetUrl`,
   il script solo ti fa vedere il link per scaricare, che si puo convogliato in qualche comando o file.

Esempio di un scaricamento commandline:

```
PS C:\Projects\Fido> .\Fido.ps1 -Win 10
No release specified (-Rel). Defaulting to '21H1 (Build 19043.985 - 2021.05)'.
No edition specified (-Ed). Defaulting to 'Windows 10 Home/Pro'.
No language specified (-Lang). Defaulting to 'English International'.
No architecture specified (-Arch). Defaulting to 'x64'.
Selected: Windows 10 21H1 (Build 19043.985 - 2021.05), Home/Pro, English International, x64
Downloading 'Win10_21H1_EnglishInternational_x64.iso' (5.0 GB)...
PS C:\Projects\Fido> .\Fido.ps1 -Win 10 -Rel List
Please select a Windows Release (-Rel) for Windows 10 (or use 'Latest' for most recent):
 - 21H1 (Build 19043.985 - 2021.05)
 - 20H2 (Build 19042.631 - 2020.12)
 - 20H2 (Build 19042.508 - 2020.10)
 - 20H1 (Build 19041.264 - 2020.05)
 - 19H2 (Build 18363.418 - 2019.11)
 - 19H1 (Build 18362.356 - 2019.09)
 - 19H1 (Build 18362.30 - 2019.05)
 - 1809 R2 (Build 17763.107 - 2018.10)
 - 1809 R1 (Build 17763.1 - 2018.09)
 - 1803 (Build 17134.1 - 2018.04)
 - 1709 (Build 16299.15 - 2017.09)
 - 1703 [Redstone 2] (Build 15063.0 - 2017.03)
 - 1607 [Redstone 1] (Build 14393.0 - 2016.07)
 - 1511 R3 [Threshold 2] (Build 10586.164 - 2016.04)
 - 1511 R2 [Threshold 2] (Build 10586.104 - 2016.02)
 - 1511 R1 [Threshold 2] (Build 10586.0 - 2015.11)
 - 1507 [Threshold 1] (Build 10240.16384 - 2015.07)
PS C:\Projects\Fido> .\Fido.ps1 -Win 10 -Rel 20H2 -Ed Edu -Lang Fre -Arch x86 -GetUrl
https://software-download.microsoft.com/db/Win10_Edu_20H2_v2_French_x32.iso?t=c48b32d3-4cf3-46f3-a8ad-6dd9568ff4eb&e=1629113408&h=659cdd60399584c5dc1d267957924fbd
```

Note addizionale
----------------
<!---
Because of its intended usage with Rufus, this script is not designed to cover every possible retail ISO downloads.
Instead we mostly chose the ones that the general public is likely to request. For instance, we currently have no plan
to add support for LTSB/LTSC Windows ISOs downloads.

If you are interested in such downloads, then you are kindly invited to visit the relevant download pages from Microsoft
such as [questa](https://www.microsoft.com/it-it/evalcenter/evaluate-windows-10-enterprise) for LTSC versions.
--->
A causa dell'uso previsto con Rufus, questo script non è stato progettato per coprire tutti i possibili download di ISO al dettaglio.
Abbiamo invece scelto principalmente quelli che il grande pubblico probabilmente richiederà. Per esempio, al momento non abbiamo in programma
di aggiungere il supporto per i download di ISO di Windows LTSB/LTSC.

Se siete interessati a tali download, vi invitiamo a visitare le relative pagine di download di Microsoft
come [questa](https://www.microsoft.com/it-it/evalcenter/evaluate-windows-10-enterprise) per le versioni LTSC.
