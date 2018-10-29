local descEN = [[This Ultimate Station mod is designed to create station with various type of platforms, it includes 4 basic types:
1. Generic Station
2. Double Curvature Station
3. Triangle Station
4. Half-Triangle Station
5. Terminal station

All 5 types have most of options and variations in common. The variations include:
* Curvature
* Platform width
* Platform height
* Platform with narrow end
* Platform with shorten length
* Platform with decentralization
* Transit tracks
* Leftmost/Rightmost platform enablers
* Roof length
* Linear slope
* Extra entries
* Station Fences
* Altitude adjustment

Under default settings, all platforms have the same length.

1. Generic Station
Station with single reference radius for all platforms
You can also use this mod to create loop station, with a small enough radius and long enough platform.

2. Double Curvature Station
Station with two reference radii for all platforms. 
It can be a station with two different radii but the same polarity, called a progressive curvature, or can be a station with two different radii of different polarity, call a counter curvature.

3. Triangle Curvature Station
Station with two different radii for two different group of platforms. 
It's usually used to create a station on bifurcation, but also can be used to create a station on crossing, called corner station.

4. Half-Triangle Curvature Station
It's like a mix of triangle station and generic station, with three different radii, of whom two are for two different group of platforms and another for all platforms.
It's also usually used to create a station on bifurcation, or to be placed at the end of a flying junction, due to spatial constraints.

5. It's like a Generic Station but in terminal format 

Options:
* Platform height: You can choose a unique height for all platforms; the available values are from railways all around the world.
* Platform width: You can choose a unique width for all platforms.
* Transit tracks: You can have up to 4 transit track for each group of tracks, and you will be able to place them on the left, right, central of two sides of all tracks of the group.
* Leftmost/Rightmost/Middle Platforms: You can choose to let mod try to have a platform on the leftist/rightest of the station, for triangle stations, you have also this option for the platform between two groups.
* Roof length: You can choose a percentage value for the length of the roof compared to the platform.
* Slope: The slope is applied linearly on each track.
* Main entry: The main entry is always on the left of the station, if the leftmost platform doesn't exist, the main entry is disabled. You can choose the longitude position of the main entry. The main entry will be on the middle platform of a triangle station if there's enough space.
* Secondary entries: there are three longitude secondary entries positions, and they can be on the left or right or both of the station. You can choose the type of entry as a ground entry or an underground one. If the leftmost/rightmost platform doesn't exist, the ground entry will be automatically converted to an underground one.
* Underground entries: these underground entries can be used for pedestrians only.
* Fences: You can have fences on the left or right or both sides of the station, no matter if there's a platform there. You can choose the color and the style of the fences.
* Altitude: You can fine adjust the altitude of the station, to make the underground entry on surface level, due to the technique limit, you can have only an max adjustment of -/+ 6m. 

Platform variations:
* Narrowest Extremity width: You can let same platforms have narrower ends that it's middle part. The option is presented in percentage.
* Shortest platform: You can have some platforms shorter than nominal length, the option is presented in percentage.
* Offset platform max: You can have some platforms decentralized build; the option is presented in percentage of the nominal length of the station.
* You need to apply a variation rule for all of three options, the input of the rule is the percentage distance of the current platform to the reference track/platform.
 - Uniform: all variations are equal regardless the distance between the applied platform and its reference
 - Linear: all variations are applied linearly. (y = x)
 - Quadratic: all variations follow the quadratic function y = x * x
 - Quartic:  all variations follow the quartic function y = x * x * x * x
 - Gaussian: all variations follow the gaussian function.
 - Gaussian 2: another gaussian, but with expected value not zero. This rule can be used to create a platform config where the shortest one is not on two sides.
* Reference: The reference, which is not affected by any variation settings, can be a track or a platform, if can be the leftmost/rightmost or the middle one.
* Unaffected platforms: The percentage of unaffected platforms among all platforms, they are all round the reference.

The Planner
The planner can be used to build station with visual input, and override the input of parameters panel. It can be used to build stations with great precision.
The planner for the moment can only be used on Generic Station and Double Curvature Station, the type of station is automatically chosen by the planner depending on their positions.
Instruction:
1. Place two markers of the same group on the extremity of the planned station. Two arrow markers should be face to face.
2. Activate "Generic Station" menu
3. Choose the same group, click on "Preview" button to enter into preview mode, configurate other parameters
4. Click on "Build" to construct the station, click on "Clear" to erase the preview
4. The length, slope and radius can be locked by the planners, you can choose the parameter source for these two them via menu
5. You can rename one of the planner to use override instructions, use the format as follows (00 means number):
- Start with #
- L00: length override e.g L120 -> Ref. length = 120m
- R00: radius override e.g R1500 -> Ref. length = 1500m
- Lr00: length round-off e.g Lr10 -> Roundoff the length by 10m
- Rr00: length round-off e.g Rr100 -> Roundoff the radius by 100m
- T/P: Track and platform configuration, T = Track, P = Platform, t = Designated Track.
   E.g PTTPtTT -> A 3-track-2-platform station with two transit tracks, and the third track is the reference track where the main curve goes through

Changelog:
1.12
- Station built with planner has now a station name board on the platform
- Fixed transit track position error on triangle station and half-triangle station
- Fixed wrong train stop position on half triangle station when common part length ≠ 50%
- Added "Length Ratio A/B" option to Double Curvature Station
1.11
- Added "Planner" function to have a ultra flexible build process (c.f description and video for use)
- Fixed wrong calculation on reference when reference is a track
- Fixed wrong calculation on transit track position
- Added the option to put the main entry to sides on triangle station
- Added French translation
1.10
- Fixed crash on certain configuration on triangle-like station
- Fixed crash on certain radius configuration on triangle-like station
1.9
- Fixed polygen error on half-triangle station when length on part A is different to part B
- Add option to adjust common radius part length

Credits for resources:
The fences B/C models are based on models from https://3dwarehouse.sketchup.com/, with modification and adaptations.
https://3dwarehouse.sketchup.com/model/b877336b50d9f04b6c5b8009db95f66f/FENSYS-SPORT2D1500
https://3dwarehouse.sketchup.com/model/485809566dba074eb43063bc39f0ebb/Curved-security-fence
]]

local descDE = [[=== Fehler Erkennung und Absturzbericht ===
Durch die Komplexität der Algorythmen kann es noch zu Abstürzen durch Berechnungsfehler kommen.
Nach der Version 1.4 werden alle Abstürze verhindert, jedoch werden die Standartparameter genutzt um den Bahnhof zu bauen.
Wenn dieser Fall eintritt, bitte den Absturzbericht (stdout) einsenden. Dies erleichtert das Debuggen und die Fehlersuche um einiges.
Die Informationen werden in der stdout.txt gespeichert, welche im Ordner 446800\local\crash_dump deines Steam-Benutzerordners.Bitte nur den letzten Abschnitt, "Ultimate Station failure" einschicken, da nur dieser benötigt wird.
=== Ende der Fehler Erkennung und Absturzbericht ===

== Sprachenbarriere ==
Noch ein Hinweis an alle deutschsprachigen. Da Enzojz kein deutsch spricht, bittet er euch als Anwender ihm auf Englisch zu schreiben.
Dies erleichtert die Kommunikation, da die Übersetzer gerne Fehler einbauen und die Nachricht oft falsch rüberkommt.
== Ende Sprachbarriere ==

Der Ultimate Station Mod wurde entwickelt um Bahnhöfe mit verschiedenen Bahnsteigtypen zu bauen. Er beinhaltet 4 Arten::
1. Generischer Bahnhof
2. Bahhof mit 2 Kurven
3. Dreieckiger Bahnhof
4. Halb-dreieckiger Bahnhof

Alle 4 Typen haben fast alle Optionen und Variationen gemeinsam. Diese beinhalten:
* Kurvenradius
* Bahnsteigbreite
* Bahnsteighöhe
* Bahnsteig mit dünnem Ende
* Bahnsteig mit kurzen Ende
* dezentralisierte Bahnsteige
* Durchfahrtsgleise
* Aktivierung / Deaktivierung der äußeren Bahnsteige
* Länge des Bahnsteigdach
* Lineare Steigung
* zusätzliche Eingänge
* Zäune 
* Höhenanpassung

Mit den Standarteinstellungen haben alle Bahnsteige die gleiche Länge.

1. Generischer Bahnhof

Bahnhof mit einem Radius für alle Bahnsteige
Zudem kannst du den Mod nutzen um dir einen Kreis zu bauen. Dazu muss der Radius klein und die Bahnsteiglänge lang genug sein.

2. Bahhof mit 2 Kurven
Bahnhof mit 2 Radien für alle Bahnsteige
Es können 2 verschiedene Radien in die Gleiche Richtung sein (Progressive Kurve), oder 2 Radien in unterschiedliche Richtung (Gegenkurve).

3. Dreieckiger Bahnhof
Bahnhof mit 2 unterschiedlichen Radien für 2 unterschiedliche Gruppen an Bahnsteigen.
Wird überlicherweise dazu verwendet, einen Bahnhof an einer Gabelung zu bauen. Sie kann jedoch auch an Kreuzungen als Eckstation gebaut werden.

4. Halb-dreieckiger Bahnhof
Eine Mischung aus dem Dreieckigen Bahnhof und dem Generischen Bahhof. Er hat drei Radien, wovon zwei für zwei unterschiedliche Bahnsteiggruppen sind und der dritte für alle Bahnsteige.
Er wird normalerweise an einer Gabelung gebaut oder aufgrund von räumlchen Einschränkungen auch an Flying Junctions.

Optionen:
* Bahnsteighöhe: Du kannst eine einheitliche Höhe für alle Bahnsteige einstellen. Die Höhen sind von Fahrzeugen aus aller Welt.
* Bahnsteigbreite: Du kannst die Breite aller Bahnsteige einstellen.
* Durchgangsgleise: Du kannst bis zu vier Durchgangsgleise für jede Gleisgruppe bauen. Dabei kannst du auswählen, ob sie Links, Rechts oder Mittig in der Gruppe platziert werden.
* Linke/Rechte/Mittlere Bahnsteige: Du kannst die Äusersten Bahnsteige weglasse. Beim dreieckigen Bahnhof besteht die Möglichkeit für den mittleren.
* Dachlänge: Du kannst die Dachlänge in Prozent bezogen auf die Bahnsteiglänge auswählen.
* Steigung: Die Steigung ist linear auf alle Gleise angewendet.
* Haupteingang: Der Haupteingang ist immer auf der linken Seite des Bahnhofes. Wenn der linke Bahnsteig nicht existiert, ist der Haupteingang deaktiviert. Du kannst die Position entlang des Bahnsteiges einstellen. Der Eingang ist auf dem mittleren Bahnsteig des dreieckigen Bahnhofes, solange genug Platz da ist.
* Nebeneingänge: Es gibt entlang des Bahnhofes drei Positionen für Nebeneingänge, die entweder links, recht oder beidseitig des Bahnhofes gebaut werden können. Die Eingänge können unter- wie auch oberirdisch sein. Wenn der äußerste Bahnsteig nicht existiert, wird der oberirdische Eingang automatisch zum unterirdischen.
* Unterirdische Eingänge: Diese Eingänge werden nur von Fußgängern genutzt.
* Zäune: Du kannst Zäune links, rechts oder beidseitig bauen, egal ob es dort einen Bahnsteig gibt oder nicht.Zudem kannst du die Farbe und den Typ des Zaunes bestimmen.
* Höhe: Du kannst die Gleishöhe des Bahnhofes einstellen. Damit kann man die Untergrundeingänge auf die Höhe des normalen Bodens einstellen. Aus technischen Gründen ist eine maximale Anpassung von +/- 6 Metern möglich.

Bahnsteig Variationen:
* kleinste Bahnsteigbreite: Du kannst gleiche Bahnsteige mit schmaleren Enden als der mittlere Teil bauen. Die Option wird in Prozent angegeben.
* kürzester Bahnsteig: Du kannst gleiche Bahnsteige prozentual kürzer bauen als die eingestellte Länge.
* maximaler Bahnsteig Versatz: Du kannst die Bahnsteige entlang der Gleise  verschieben. Die Option arbeitet prozentual zur Länge der Station.
* Du musst eine Regel für alle drei Optionen anwenden. Die Regel bestimmt die prozentuale Distanz des aktuellen Bahnsteiges zum Referenzbahnsteige /-gleis.
 - Einheitlich: Alle Variationen sind gleich, unabhänging von der Distanz zwischen dem aktuellen Bahnsteig und der Referenz
 - Linear: Alle Variationen folgen der Funktion (y = x)
 - Quadratisch: Alle Variationen folgen der quadratischen Funktion  y = x * x
 - Bi-Quadratisch:  Alle Variationen folgen der Bi-Quadratischen Funktion  y = x * x * x * x
 - Gaussian: Alle Variationen folgen der Gaussianischen Funktion.
 - Gaussian 2: Eine weitere Gaussian Funktion, jedoch wirt kein Wert mit 0 erwartet. Mit dieser Regel lassen sich Bahnsteige bauen, wo der kürzeste nicht auf zwei Seiten ist.
* Referenz: Die Referenz, welche nicht durch irgendwelche Variationseinstellungen beinflusst wird, kann ein Gleis oder Bahnsteig sein, der ganz links, rechts oder mittig ist.
* Unbeeinflusster Bahnsteig: Der Prozentuale Wert von unbeeinflussten Bahnsteigen entlang aller Bahnsteige, die alle um die Referenz sind.

Unterschied zwischen den 4 Bahnhöfen:
Das folgende Wissen wird dir helfen die Eigenschaften der Bahnhöfe zu verstehen.
Der Generische Bahnhof und der Bahnhof mit 2 Kurven sind auf zwei unterschiedliche Kurvenberechnungs Algorythmen basiert. Um es einfach zu sagen, beim generischen Bahnhof hat jeder Bahnsteig sein lineares Zentum als Referenzpunkt, in dem Bahnhof mit 2 Kurven  ist der Referenzpunkt für jeden Bahnsteig der Ausgangspunkt des Bahnhofes. Der Unterschied kann bemerkt werden, wenn man den Versatz der Bahnsteige aktiviert.
Der Halb-dreieckige Bahnhof arbeitet nach dem gleichen Algorythmus wie der Bahnhof mit 2 Kurven.
Jeder Bahnsteig des Dreieckigen Bahnsteig hat seinen Refernzpunkt an der Stelle, wo zwei Gruppen sich treffen.

Was ist als nächstes  geplant?
Der Mod ist nicht fertig, auch wenn ich bis jetzt 5 Montage daran gearbeitet habe. Die veröffentlichung ist ein Erfolg. Die Mod kann benutzt werden und das meiste der Arbeit ist erledigt. Der nächste Schritt wird sein, den Mod zu erweitern / verbessern, z.B. Die Gebäude und Bahnsteige der älteren Era einzubauen. Auch werde ich eine Terminal Version und Güter version bauen.
Durch due Komplexität des Algorythmus, den ich verwendet habe, kann es zu crashes unter bestimmten Bedingungen kommen. BITTE DIESE CRASHES MIT DEN SETTINGS MELDEN.
Ich werde die Elevated Station und den Untergrund Bahnhof auf die selbe Basis updaten, und vileicht auch die Track Design Patterns und Flying Junktions updaten.

Meine Ostereier, Ich hoffe es gefällt euch :D

Versionsänderungen:
1.5
- Unbenutzbarer Haupteingang beim Dreieckigen Bahnhof (Winkel annähernd 90°) gefixxt
- Visuellen Zaunbug behoben
1.4 
- Informationsspeicherung im Crashfall & Automatische Widerherstellung
1.3
- Unterstützung der Common API
1.2
- Absturz bei Assertionsfehler behoben
- Absturz ohne Fehlermeldung behoben
- Chinesische Übersetzung hinzugefügt
1.1
- Absturz mit R = 50 behoben
- Falsche Passagierblickrichtung behoben
- Deutsche Übersetzung hinzugefügt
* Wichtig: Um R=50 zu nutzen, muss die Refferenz auf das rechte Gleis gestellt werden, da sonst der Kurvenradius zu klein ist.


Credit:
RPGFabi für die deutsche Übersetzung.

Credits für verwendete Ressourcen:
Die Zäune B/C basieren auf die Modelle von https://3dwarehouse.sketchup.com/. Sie wurden modifiziert und erweitert.
https://3dwarehouse.sketchup.com/model/b877336b50d9f04b6c5b8009db95f66f/FENSYS-SPORT2D1500
https://3dwarehouse.sketchup.com/model/485809566dba074eb43063bc39f0ebb/Curved-security-fence
]]

local descCN = [[终极车站用于创建各种变化的站台，它包括四种基本类型： 
1.普通车站 
2.双曲线车站 
3.三角车站 
4.半三角车站 
5.尽头站

所有5种类型都有大部分共同的变化选项，包括： 
* 曲率 
* 站台宽度 
* 站台高度 
* 收紧的站台端部 
* 最短的站台长度 
* 收紧的站台端部 
* 正线数 
* 是否设置最左/最右的站台 
* 雨棚长度 
* 线性坡度 
* 出口 
* 车站围栏 
* 高度调整 

在默认设置下，所有站台的长度均相同。 

1.普通车站 
所有站台都使用单参考半径 
你也可以使用它建造一个灯泡线车站，只要有足够小的半径和足够长的站台。 

2.双曲线车站 
所有站台都有两个参考半径。 
它可以是一个具有两个不同半径但相同方向的曲线，称为渐进曲线，或者可以是具有两个不同方向的曲线，称为反向曲线。 

3.三角车站 
两个不同半径用于创建两组不同方向的站台。 
它通常用于线路分叉点上，但也可用于在线路交叉点上，称为角式站点。 

4.半三角车站 
三角车站和普通车站的混合体，有三种不同的半径，其中两种用于两组不同的站台，另一种用于所有站台。 
它通常也用于在线路分岔处，或者将其放置在疏解的末端。 

5.尽头车站
和普通车站类似，但是车站是尽头式。

选项： 
* 站台高度：您可以为所有站台选择独特的高度，可选的值来自世界各地的铁路。 
* 站台宽度：您可以为所有站台选择一个统一的宽度。 
* 正线数：最多可以设置四条正线轨道，您可以将它们放置在所有轨道左侧、右侧、中央或者两侧。 
* 左侧/右侧/中间站台：您可以选择尝试在车站的左侧/右侧强制设置站台，对于三角车站，您也可以在两组轨道之间设置一个站台。 
* 雨棚长度：您可以选择雨棚长度与站台相比的百分比值。 
* 坡度：在每条轨道独立线性坡度。 
* 主入口：主入口始终位于车站左侧，如果最左侧的站台不存在，主入口是无法设置的。您可以选择主入口的纵向位置。 如果有足够的空间，主入口将位于三角车站的中间站台上。 
* 次入口：在纵向方向上有三个可以设置次要入口的位置，它们可以位于左侧、右侧或者两者。您可以选择地面入口或地下入口作为入口类型。如果最左边/最右边的站台不存在，地面入口将自动转换为地下入口。 
* 地下入口：这些地下入口只能用于行人通过。 
* 栅栏：无论站台是否有站台，您都可以在火车站的左侧或右侧或两侧设置栅栏。 您可以选择栅栏的颜色和风格。 
* 高度：您可以精确调整台站的高度，使地下入口位于地表，由于技术限制，您只能进行最大正负6米的调整。 

站台变换： 
* 收紧的站台端部：您可以让一个站台的两端部分变窄。 该选项以百分比表示。 
* 最短的站台长度：您可以让有一些站台短于名义长度，选项以百分比表示。 
* 最大的站台平移：你可以让有一些站台偏离中心设置; 该选项以车站名义长度的百分比表示。 
* 您需要为所有三个选项应用计算规则，规则的输入是当前站台与参考轨道或者参考站台的百分比距离。 
 - 归一：无论应用站台与其参考之间的距离如何，所有变化均相等 
 - 线性：所有变化都是线性变化的。(y = x) 
 - 二次：所有变量都遵循二次函数 y = x * x 
 - 四次：所有变体都遵循四次函数 y = x * x * x * x 
 - 高斯：所有变体都遵循高斯函数。 
 - 高斯2：另一个高斯，但期望值不为零。此规则可用于创建最短站台不在两侧的配置。 
* 参照物：参照物不受任何变化设置影响，可以是轨道或站台，可以是最左侧/最右侧或中间的。 
* 未受影响的站台：所有车站中未受影响站台的百分比，他们都在参照物两侧。 

规划工具
规划工具可以提供以可视化方式建造车站的方法，用这个方法可以替代一些通过参数面板进行的参数输入。目前该工具只能用在普通和双曲线车站上，规划工具会依据给定的位置自动选择合适的车站类型。

使用方法:
1. 在地图上放置两个同组的规划标志。规划标志的箭头必须是相对朝内的。
2. 激活“普通车站”建造菜单
3. 选择和规划标志相同的组，点击“预览/刷新”进入预览模式，然后可以调整其他参数
4. 点击“建造”建造车站，点击“清楚”删除预览
4. 车站长度和坡度可以通过规划工具计算提供，你可以在菜单中选择他们的参数来源
5. 你可以用修改其中一个规划工具的名称用来执行“强制指令”，强制指令的格式如下，00表示数字：
 - 以#开始
 - L00: 强制长度，比如 L120 -> 长度 = 120m
 - R00: 强制半径，比如 R1500 -> 半径 = 1500m，该参数只有在普通车站类型中有效
 - Lr00: 强制长度取整 比如 Lr10 -> 长度以10m取整
 - Rr00: 强制半径取整 比如 Rr100 -> 半径以100m取整
 - T/P: 轨道和站台布局配置, T = 轨道, P = 站台, t = 指定参照轨道（主曲线通过的轨道）。
   比如 PTTPtTT -> 一个三轨道两站台车站，有两条正线在外侧，其中第三条轨道是参照轨道。

更新日志：
1.12
- 用规划工具建造的车站拥有站台牌（仅拉丁站名有效）
- 修正了三角车站中正线位置的错误
- 修正了半三角车站中共用部分长度不为50%时列车不停靠站台中间的问题
- 增加了双曲线车站A/B部分长度之比
1.11
- 增加了规划工具得以灵活的方式建造车站
- 修复了错误的正线位置计算
- 增加了三角车站主入口位置的选项
- 增加了法语翻译
1.10
- 修复了三角车站类在某些长度下的游戏奔溃
- 修复了三角车站类在某些半径下的游戏奔溃
1.9
- 修复了半三角车站下A/B部分长度不同导致的多边形渲染错误
- 增加了调整半三角车站共用半径部分长度的选项
1.8
- 增加了主入口左右侧位置的选项
- 修复了三角车站下A/B部分长度不同导致的多边形渲染错误
1.7
- 增加了尽头式车站
1.6
- 重写了三角和半三角车站中央站台的建模算法使得中央站台长度和其他站台长度一致
- 修复了在坡道曲线站台上，雨棚支撑柱横向倾斜的问题 
1.5
- 修正了三角车站在接近大角度时主入口失效的问题
- 修正了一个围栏显示错误
1.4
- 增加了避免游戏退出的措施和帮助Bug报告的信息记录
1.3
- 增加了CommonAPI支持
1.2
- 修正了断言失败导致的游戏退出
- 修正了某些没有任何提示的游戏退出
- 增加了中文描述
1.1 
- 修正R = 50时的游戏崩溃 
- 修正了错误的乘客等待方向 
- 增加了德语描述 
*注意：对于R = 50，您需要将参考改为“左侧”的“轨道”以避免无法建设的提示。 

资源： 
围栏B / C模型基于https://3dwarehouse.sketchup.com/中的模型，并进行了修改。 
https://3dwarehouse.sketchup.com/model/b877336b50d9f04b6c5b8009db95f66f/FENSYS-SPORT2D1500 
https://3dwarehouse.sketchup.com/model/485809566dba074eb43063bc39f0ebb/Curved-security-fence 

感谢：
感谢谷歌翻译的存在，否则这个中文介绍真要花我不少时间 XD
]]

function data()
    return {
        en = {
            ["name"] = "Ultimate Station",
            ["desc"] = descEN,
        },
        de = {
            ["name"] = "Ultimate Station",
            ["desc"] = descDE,
            ["Number of tracks"] = "Anzahl an Gleisen",
            ["Transit Tracks"] = "Durchfahrtsgleise",
            ["Position"] = "Position",
            ["Left"] = "Links",
            ["Centre"] = "Zentrum",
            ["Sides"] = "Seiten",
            ["Right"] = "Rechts",
            ["Radius"] = "Radius",
            ["Platform"] = "Bahnsteig",
            ["Length"] = "Länge",
            ["Outter"] = "Außen",
            ["Polarity"] = "Richtung",
            ["Platform Variation"] = "Bahnsteig Variation",
            ["Narrowest Extremity Width"] = "Schmälste Breite",
            ["Uniform"] = "Einheitlich",
            ["Linear"] = "Linear",
            ["Quadratic"] = "Quadratisch",
            ["Quartic"] = "Bi-Quadratisch",
            ["Gaussian"] = "Gaußsche",
            ["Gaussian 2"] = "Gaußsche 2",
            ["Shortest Platform"] = "Kürzester Bahnsteig",
            ["Offset Platform Max."] = "Maximaler Bahnsteigversatz",
            ["Track"] = "Schiene",
            ["Reference"] = "Referenz",
            ["Center"] = "Zentrum",
            ["Unaffected platforms"] = "Unbeinflusste Bahnsteige",
            ["Main Entry"] = "Haupteingang",
            ["None"] = "Keiner",
            ["Central"] = "Zentral",
            ["Both"] = "Beide",
            ["Entry"] = "Eingang",
            ["Underground"] = "Untergrund",
            ["Surface"] = "Oberfläche",
            ["Fences"] = "Zäune",
            ["Fences Style"] = "Zauntyp",
            ["Fences Color"] = "Zaunfarbe",
            ["White"] = "Weiß",
            ["Green"] = "Grün",
            ["Yellow"] = "Gelb",
            ["Slope"] = "Steigung",
            ["General Altitude"] = "Allgemeine Bauhöhe",
            ["Height"] = "Höhe",
            ["Width"] = "Breite",
            ["Leftmost Platform"] = "Linker Bahnsteig",
            ["Central Platform"] = "Mittlerere Bahnsteige",
            ["Rightmost Platform"] = "Rechter Bahnsteig",
            ["No"] = "Nein",
            ["Yes"] = "Ja",
            ["Convering Angle"] = "Winkel",
            ["Roof length"] = "Dachlänge",
            
            -- ["Progressive/Counter Curvature Station"] = "Progressiver/Konzentrischer Bahnhof mit Radius",
            ["Station that platform and track parameters can be fine-tuned, with two different radii at two extremities of the platforms."] = "Bahnhof mit Bahnsteig und Gleis Parametern um 2 verschiedene Radien an 2 verschiedenen Enden der Bahnsteige zu bauen.",
            ["Half-triangle Station"] = "Halb dreieckiger Bahnhof",
            ["Station that platform and track parameters can be fine-tuned, with two different radii on two sides of the station for half of the platforms, and one consistent radius for the other half."] = "Bahnhof mit Bahnsteig und Gleis Parametern um Bahnhöfe mit 2 unabhängigen Radien am einen Ende und einem festen Radius am anderen Ende zu bauen.",
            ["Triangle Station"] = "Dreieckiger Bahnhof",
            ["Station that platform and track parameters can be fine-tuned, with two different radii on two sides of the station."] = "Bahnhof mit Bahnsteig und Gleis Parametern um einen Bahnhof mit 2 unterschiedlichen Radien zu bauen.",
            ["Generic Station"] = "Generischer Bahnhof",
            ["Station that platform and track parameters can be fine-tuned, with single reference radius."] = "Bahnhof mit Bahnsteig und Gleis Parametern um Bahnhöfe mit einzelnen Radien zu bauen."
        },
        zh_CN = {
            ["name"] = "终极车站",
            ["desc"] = descCN,
            ["Number of tracks"] = "轨道数",
            ["Transit Tracks"] = "正线数",
            ["Position"] = "位置",
            ["Left"] = "左",
            ["Centre"] = "中",
            ["Sides"] = "两边",
            ["Right"] = "右",
            ["Radius"] = "半径",
            ["Platform"] = "站台",
            ["Length"] = "长度",
            ["Outter"] = "外侧",
            ["Polarity"] = "极性",
            ["Platform Variation"] = "站台变化",
            ["Narrowest Extremity Width"] = "收紧的站台端部",
            ["Uniform"] = "归一",
            ["Linear"] = "线性",
            ["Quadratic"] = "二次函数",
            ["Quartic"] = "四次函数",
            ["Gaussian"] = "高斯函数",
            ["Gaussian 2"] = "高斯函数2",
            ["Shortest Platform"] = "最短的站台长度",
            ["Offset Platform Max."] = "最大的站台平移",
            ["Track"] = "轨道",
            ["Reference"] = "参照物",
            ["Center"] = "中",
            ["Unaffected platforms"] = "不受变化影响的站台",
            ["Main Entry"] = "主站房",
            ["None"] = "无",
            ["Central"] = "中央",
            ["Both"] = "所有",
            ["Entry"] = "入口",
            ["Underground"] = "地道",
            ["Surface"] = "地面",
            ["Fences"] = "围栏",
            ["Fences Style"] = "围栏风格",
            ["Fences Color"] = "围栏颜色",
            ["White"] = "白色",
            ["Green"] = "绿色",
            ["Yellow"] = "黄色",
            ["Slope"] = "坡度",
            ["General Altitude"] = "整体高度",
            ["Height"] = "高度",
            ["Width"] = "宽度",
            ["Leftmost Platform"] = "左侧站台",
            ["Central Platform"] = "中央站台",
            ["Rightmost Platform"] = "右侧站台",
            ["No"] = "无",
            ["Yes"] = "有",
            ["Convering Angle"] = "夹角",
            ["Roof length"] = "雨棚长度",
            ["Central Platforms Common Block Length"] = "中央站台共享区域长度",
            ["Common Radius Part Length"] = "共半径部分长度",
            ["Main entry to central platform"] = "入口位于中央站台",
            ["Never"] = "从不",
            ["Possible"] = "可能",
            ["Use Planner"] = "规划工具",
            ["Preview/Refresh"] = "预览/刷新",
            ["Build"] = "建造",
            ["Clear"] = "清除",
            ["Planner Group"] = "规划分组",
            ["Length Source"] = "车站长度依据",
            ["Slope Source"] = "车站坡度依据",
            ["Menu"] = "菜单",
            ["Instructions"] = "指令",
            ["Planner positions"] = "规划标志位置",
            ["Length Ratio A/B"] = "A/B 长度之比",

            ["Ultimate Station Planner"] = "车站规划工具",
            ["Progressive/Counter Curvature Station"] = "渐进曲线/反向曲线车站",
            ["Station that platform and track parameters can be fine-tuned, with two different radii at two extremities of the platforms."] 
            = "在车站前后两部分拥有不同曲率曲线的，可以进行站台参数微调的车站",
            ["Half-triangle Station"] = "半三角车站",
            ["Station that platform and track parameters can be fine-tuned, with two different radii on two sides of the station for half of the platforms, and one consistent radius for the other half."] 
            = "在车站前后两部分拥有不同曲率曲线的，其中一部分可以分为两个方向的，可以进行站台参数微调的三角形车站",
            ["Triangle Station"] = "三角车站",
            ["Station that platform and track parameters can be fine-tuned, with two different radii on two sides of the station."] 
            = "分为两个方向的，可以进行站台参数微调的三角形车站.",
            ["Generic Station"] = "普通车站",
            ["Station that platform and track parameters can be fine-tuned, with single reference radius."] 
            = "拥有一个参考曲率，可以进行站台参数微调的车站.",
            ["Terminal Station"] = "尽头式车站",
            ["Terminal Station that platform and track parameters can be fine-tuned, with single reference radius."] 
            = "拥有一个参考曲率，可以进行站台参数微调的尽头式车站.",
        },
        fr_FR = {
            ["name"] = "Gare ultime",
            ["desc"] = descEN,
            ["Number of tracks"] = "Nombre de voie",
            ["Transit Tracks"] = "Nombre de voie centrale",
            ["Position"] = "Position",
            ["Left"] = "Gauche",
            ["Centre"] = "Centre",
            ["Sides"] = "Côtes",
            ["Right"] = "Droit",
            ["Radius"] = "Rayon",
            ["Platform"] = "Quai",
            ["Length"] = "Longeur",
            ["Outter"] = "Exterieur",
            ["Polarity"] = "Polarité",
            ["Platform Variation"] = "Variation de plateforme",
            ["Narrowest Extremity Width"] = "Largeur réduit d'extrémité",
            ["Uniform"] = "Uniforme",
            ["Linear"] = "Linéaire",
            ["Quadratic"] = "Quadratique",
            ["Quartic"] = "Quartique ",
            ["Gaussian"] = "Gaussien",
            ["Gaussian 2"] = "Gaussien2",
            ["Shortest Platform"] = "Longueur plus réduit",
            ["Offset Platform Max."] = "Decalage maxi.",
            ["Track"] = "Voie",
            ["Reference"] = "Référenceiel",
            ["Center"] = "Centre",
            ["Unaffected platforms"] = "Quai non varié",
            ["Main Entry"] = "Entrée principale",
            ["None"] = "Aucun",
            ["Central"] = "Centrale",
            ["Both"] = "Tous",
            ["Entry"] = "Entrée",
            ["Underground"] = "Sous-terrain",
            ["Surface"] = "Surface",
            ["Fences"] = "Clôture",
            ["Fences Style"] = "Style",
            ["Fences Color"] = "Couleur",
            ["White"] = "Blanc",
            ["Green"] = "Vert",
            ["Yellow"] = "Jeune",
            ["Slope"] = "Gradient",
            ["General Altitude"] = "Altitude générale",
            ["Height"] = "Hauteur",
            ["Width"] = "Largeur",
            ["Leftmost Platform"] = "Quai plus gauche",
            ["Central Platform"] = "Quai central",
            ["Rightmost Platform"] = "Quai plus droite",
            ["No"] = "Non",
            ["Yes"] = "Oui",
            ["Convering Angle"] = "Angle de convergence",
            ["Roof length"] = "Longeur de toit",
            ["Central Platforms Common Block Length"] = "Longeur partagé du quai central",
            ["Common Radius Part Length"] = "Longueur du courbe partagé",
            ["Main entry to central platform"] = "Entrée principale à quai central",
            ["Never"] = "Jamais",
            ["Possible"] = "Possible",
            ["Use Planner"] = "Planificateur",
            ["Preview/Refresh"] = "Aperçu/MàJ",
            ["Build"] = "Construction",
            ["Clear"] = "MàZ",
            ["Planner Group"] = "Groupement de planification",
            ["Length Source"] = "Réf. de longueur",
            ["Slope Source"] = "Réf de gradient",
            ["Menu"] = "Menu",
            ["Instructions"] = "Instructions",
            ["Planner positions"] = "Localisation de planificateur",
            ["Length Ratio A/B"] = "Rapport Longueur A/B",

            ["Ultimate Station Planner"] = "Planificateur de gare",
            ["Progressive/Counter Curvature Station"] = "Gare sur courbes des rayons différents",
            ["Station that platform and track parameters can be fine-tuned, with two different radii at two extremities of the platforms."] 
            = "Gare ayant quais et voies sur deux courbes différents, avec possibilité de varier les largeur, longueur et les positions des quais.",
            ["Half-triangle Station"] = "Gare en demi-triangle",
            ["Station that platform and track parameters can be fine-tuned, with two different radii on two sides of the station for half of the platforms, and one consistent radius for the other half."] 
            = "Gare ayant quais et voies sur deux courbes des rayons différents sur une partie du côté gauche et du côté droite, et un courbe unifié sur une partie commune, avec possibilité de varier les largeur, longueur et les positions des quais.",
            ["Triangle Station"] = "Gare en triangle",
            ["Station that platform and track parameters can be fine-tuned, with two different radii on two sides of the station."] 
            = "Gare ayant quais et voies sur deux courbes des rayons différents sur le côté gauche et le côté droite, avec possibilité de varier les largeur, longueur et les positions des quais.",
            ["Generic Station"] = "Gare générale",
            ["Station that platform and track parameters can be fine-tuned, with single reference radius."] 
            = "Gare ayant quais et voies un courbe unifié, avec possibilité de varier les largeur, longueur et les positions des quais.",
            ["Terminal Station"] = "Gare terminale",
            ["Terminal Station that platform and track parameters can be fine-tuned, with single reference radius."] 
            = "Gare termiale ayant quais et voies un courbe unifié, avec possibilité de varier les largeur, longueur et les positions des quais.",
        }
    }
end
