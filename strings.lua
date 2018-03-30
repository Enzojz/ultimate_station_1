local descEN = [[This Ultimate Station mod is designed to create station with various type of platforms, it includes 4 basic types:
1. Generic Station
2. Double Curvature Station
3. Triangle Station
4. Half-Triangle Station

All 4 types have most of options and variations in common. The variations include:
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

Difference between 4 types of the stations:
The following knowledge will help you understand some behavior of the station
The generic station and double curvature are actually base on two different curve generation algorithms. In simple words, in general station, each platform has its linear central as it's reference point, and in double curvature station, the reference point of each platform is origin point of the station, the difference can be noticed when you apply the offsets then other variations on platforms.
The half-triangle curvature station is actually works on the same algorithm as the one for double curvature station.
Each platform in a triangle station has its reference point on the place where two groups comes together.

What's the next?
The mod is not finished, though I have spent 5 months since the begin. The release of it is a stage achievement -- it can be used and most of the programming work is done. The next stage will be enhancing it, including introducing old era station models and old era platform models. Also, I will introduce the terminal version and the cargo version.
Due to the complicity of the algorithm I have applied, this mod may crash, under certain circumstances, please report the crash with the settings you have applied.
I will upgrade the elevated station and the underground station on the same base, maybe also to improve the track design pattern and the flying junction.

My Easter eggs, hope you like it.

Credit:
RPGFabi for German translation.

Credits for resources:
The fences B/C models are based on models from https://3dwarehouse.sketchup.com/, with modification and adaptations.
https://3dwarehouse.sketchup.com/model/b877336b50d9f04b6c5b8009db95f66f/FENSYS-SPORT2D1500
https://3dwarehouse.sketchup.com/model/485809566dba074eb43063bc39f0ebb/Curved-security-fence
]]

function data()
    return {
        en = {
            ["name"] = "Ultimate Station",
            ["desc"] = descEN,
        },
        de = {
            ["name"] = "Ultimate Station",
            ["desc"] = descEN,
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
            ["desc"] = descEN,
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
            = "拥有一个参考曲率，可以进行站台参数微调的车站."
        }
    }
end
