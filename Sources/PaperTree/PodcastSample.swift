// A real episode, recorded for design snapshots: the script was written by the podcast endpoint
// from the snapshot sample paper, and the peaks are the loudness of its real audio (Gemini TTS).
// Nothing here runs in normal use.
import Foundation

enum PodcastSample {
    static let title = "How Plants Trade Water For Carbon"
    static let duration = 211.14
    static let lines: [(String, String, String, String, Double, Double)] = [
        ("Juniper", "Why should I care about how plants deal with dry soil? Don't they just wilt and wait for rain?", "", "", 0.00, 5.34),
        ("Rowan", "It is actually a smart balancing act. The paper Leaves in a dry spell: how plants trade water for carbon explains how leaves trade water to get carbon.", "Leaves in a dry spell: how plants trade water for carbon", "Title", 5.96, 16.08),
        ("Juniper", "Wait, how does a plant trade water for carbon?", "", "", 16.77, 19.17),
        ("Rowan", "Plants need carbon dioxide from the air to make food, but when they open tiny leaf pores called stomata to get it, water escapes.", "Under drought, plants close their stomata to save water.", "1. Introduction", 19.70, 26.47),
        ("Juniper", "So stomata are basically tiny doors on the leaf surface?", "", "", 26.87, 31.55),
        ("Rowan", "Exactly. Under drought, the plant closes those doors to save water, which limits transpiration, or water loss.", "Under drought, plants close their stomata to save water. That limits transpiration", "1. Introduction", 32.02, 38.69),
        ("Juniper", "Okay, saving water sounds great. What is the downside?", "", "", 39.32, 42.28),
        ("Rowan", "When the doors shut, leaf temperature rises because water is not evaporating to cool it off.", "so leaf temperature rises, and with less carbon dioxide reaching the chloroplasts", "1. Introduction", 42.83, 47.56),
        ("Juniper", "And less carbon dioxide gets inside too, right?", "", "", 48.30, 51.32),
        ("Rowan", "Right. With less carbon dioxide reaching the chloroplasts, photorespiration increases and net carbon assimilation falls.", "photorespiration increases and net carbon assimilation falls.", "1. Introduction", 51.76, 60.05),
        ("Juniper", "Huh? What are photorespiration and net carbon assimilation?", "", "", 60.68, 64.82),
        ("Rowan", "Net carbon assimilation just means the net amount of carbon the plant takes in to grow. Photorespiration is a side reaction that wastes energy.", "The enzyme that fixes carbon, Rubisco, works best when carbon dioxide is plentiful inside the leaf.", "2. Why the trade costs carbon", 65.56, 74.25),
        ("Juniper", "Why does that side reaction happen?", "", "", 75.13, 76.97),
        ("Rowan", "There is an enzyme called Rubisco that fixes carbon. But Rubisco also reacts with oxygen, especially when carbon dioxide levels inside the leaf drop.", "Rubisco also reacts with oxygen, and that side reaction becomes more common as carbon dioxide inside the leaf drops.", "2. Why the trade costs carbon", 77.60, 86.83),
        ("Juniper", "So if carbon dioxide drops, Rubisco grabs oxygen instead and wastes energy?", "", "", 87.49, 92.83),
        ("Rowan", "Yes, the plant spends energy recovering carbon it had already fixed.", "The plant then spends energy recovering carbon it had already fixed.", "2. Why the trade costs carbon", 93.42, 97.46),
        ("Juniper", "Do all plants suffer from this wasteful oxygen reaction?", "", "", 98.04, 102.76),
        ("Rowan", "Not equally. Plants with C4 metabolism concentrate carbon dioxide around Rubisco and lose less carbon this way.", "Plants with C4 metabolism concentrate carbon dioxide around Rubisco and lose less this way", "2. Why the trade costs carbon", 103.41, 110.53),
        ("Juniper", "Okay, so C4 plants are like specialized grasses built for hot, dry places.", "", "", 110.97, 115.29),
        ("Rowan", "That is right. That is one reason many grasses of hot, dry places use C4 metabolism.", "which is one reason many grasses of hot, dry places use it.", "2. Why the trade costs carbon", 115.92, 120.97),
        ("Juniper", "How does the leaf even know the soil is dry in the first place?", "", "", 121.80, 124.85),
        ("Rowan", "Stomata do not wait for the leaf to wilt. As soil dries, roots send chemical signals upward.", "Stomata do not wait for the leaf to wilt. As soil dries, roots send chemical signals upward", "3. Signals from the roots", 125.52, 130.67),
        ("Juniper", "So the roots warn the leaves before they actually run out of water?", "", "", 131.35, 135.30),
        ("Rowan", "Yes, guard cells respond within hours. The leaf acts cautious early, closing partly before damage occurs.", "and guard cells respond within hours. The result is a leaf that is cautious early", "3. Signals from the roots", 135.71, 141.81),
        ("Juniper", "What happens after it rains?", "", "", 142.51, 148.01),
        ("Rowan", "The leaf recovers slowly after rain while those root signals fade away.", "and that recovers slowly after rain while the signals fade.", "3. Signals from the roots", 151.94, 152.21),
        ("Juniper", "So does a short, intense drought hurt a plant more than a long, mild one?", "", "", 152.37, 153.60),
        ("Rowan", "Actually, no. A season of mild drought often costs more growth than a short severe one.", "A season of mild drought often costs more growth than a short severe one", "4. What this means for growth", 154.16, 159.61),
        ("Juniper", "Wait, why would a mild drought cost more total growth?", "", "", 160.43, 163.24),
        ("Rowan", "Because the leaf spends many days partly closed, missing out on carbon day after day.", "because the leaf spends many days partly closed.", "4. What this means for growth", 163.78, 169.13),
        ("Juniper", "Can scientists use this to breed better crops?", "", "", 169.90, 172.16),
        ("Rowan", "Breeding for crops that keep stomata open a little longer, without running out of water, is an active line of work.", "Breeding for crops that keep stomata open a little longer, without running out of water, is an active line of work.", "4. What this means for growth", 172.71, 178.17),
        ("Juniper", "Are there actual figures or crop yield numbers in this paper?", "", "", 179.09, 181.70),
        ("Rowan", "No, the text explicitly notes that it is a sample text and has no real figures.", "The figures in a real paper would show these curves; this sample text has none.", "4. What this means for growth", 182.77, 187.74),
        ("Juniper", "So we do not know specific crop types or exact water savings from this paper?", "", "", 188.34, 192.05),
        ("Rowan", "That is right, those details are not covered here.", "", "", 192.64, 196.04),
        ("Juniper", "What is the main thing to remember about how plants handle drought?", "", "", 196.48, 199.44),
        ("Rowan", "When soil dries, plants save water by closing leaf pores early, but that safety comes at the cost of slower growth.", "how leaves balance water loss against carbon uptake when soil dries", "Abstract", 200.39, 207.10),
        ("Juniper", "That makes total sense. Thanks for breaking it down, Rowan!", "", "", 207.77, 210.70),
    ]
    /// Loudness in 640 steps, one character each (0 quiet to z loud).
    static let peaks = "yzlvwiiiganhsmksc1zozupn61rttnvs5kkqvgt9elsstzplh0gqtnnont62zozxtnwhs2vxkzlrjtuxjprg0cvzpg1ljice1w92pohkwrmfphgqisknp80msvsnivqj25zyplhkr9myrsjr50soqwvtppzq0zooxtzunspa4voqpehhkullki32r0zrzsvmjijib0imztphnxyptigkdt1rypolnon8a30huvyem50wpvohkbhii2pssuqrf7poqzllkhc40xhyznwaroqxjrldkj0sdenpqltuvyk30zzvutsxqsi1kzqg0pvnxvtjawrqztrrmqgoqp82ntoopjcnfgip870nx4zwzuhonihlmg700rkjrlqphea0dzzsrf1cvxkojmjf20vfhhgnefl50w4utoqk50klrmh02oqqhi00wqja0nqpzqa4knlh900111111111bcmdhk0kzwjsrrrjjfvymnmf00zhttylomr1fxowrqcrvfnsqdpfh00vrmktti0rsvlmwmtlmsquhoou50ozinjnnjg000w6umlmssjjfhlg935qlqgeqiknljb1yt1fyzopjc38tvllkbdh900pvxpmnummeoigcjlkldmh15ripiyurzi0"

    static func episode(paperId: String) -> PodcastEpisode {
        let digits = Array("0123456789abcdefghijklmnopqrstuvwxyz")
        let p = peaks.map { c in Float(digits.firstIndex(of: c) ?? 0) / 35 }
        let ls = lines.enumerated().map { i, l in
            PodcastLine(id: i, speaker: l.0, text: l.1, quote: l.2, section: l.3, sig: "", start: l.4, end: l.5)
        }
        return PodcastEpisode(paperId: paperId, title: title, lines: ls, duration: duration, peaks: p, made: Date(), take: 0,
                              source: "paper", scriptModel: "gemini-3.5-flash", voiceModel: "gemini-3.8-flash-lite-tts", audioFile: "sample.m4a")
    }
}
