Who does this realistically serve? my own words. no ai.

Everyone. Not a bank account, not an ego.

Hundreds if not thousands of people are still running these cars. Commodores are one of the most available platforms in U-Pull-It yards and old wreckers across Australia. People use these PCMs and engines for dirt circuit, drag racing, drifting, and daily driving. The barrier to making these cars run well should not be money or gatekeeping.

There are people who have been tuning these ECUs for years, many underground, many retired. The ones still doing it either have months-long wait lists or steer customers toward buying a specific ECU they happen to sell. pcmhacking.net is free. This GitHub is free. But the people who understand these PCMs either disappear, can't teach, or charge for their time because it took them years to learn what they know. Nobody should have to spend 10 years digging through forum threads or bricking ECUs to get where they could be in weeks with the right documentation.

This project exists to be a definitive, testable, falsifiable source of what works and what doesn't on the Delco 445 92118883 platform. RAM maps, hook points, patch methods, scope data, all in one place. No one should have to re-map RAM variables from scratch when someone already has the answers. The method needs to be defined clearly enough that it works for the old-school people who have done this before and the people trying to start in 2026 who can't find answers buried across 100-page forum threads at 10 posts per page.

Why Delco is harder than other ECUs: European ECUs from the same era used 512KB to 1MB EEPROMs on C166/C167 processors, with a separate TCM handling transmission. Delco put the engine and transmission calibration and code into one PCM at a quarter to an eighth of the memory. You can't just zero the dwell. You can't just make an XDF and call it a patchlist. No one outside of HP Tuners has succeeded in making a public GM or Holden patchlist, only commercial tools have them. This is the most tightly optimised calibration and code of any ECU from that period, which makes it harder to custom code but also more rewarding when it works.

For the dirt circuit community still running Delco 808 ECUs, a flash-based option with a bigger EEPROM and better spark control than 12P is practical. Flash in car, log and flash through the same cable, no need to buy a separate programmer or learn an extra step that doesn't apply to this platform.

On patch implementation: there is no single correct method. If one spark cut variant works and another works with a different approach, and both are different from The1's and VL400's 11P method on 424, then all are genuine, just different in sound and effect. There are hundreds of combinations of max RPM, hysteresis amount, and timing retard. Multiple patched bins will be needed, each with their own tuning XDF and methods, each studied for effects in car and on scope.

Where the C compiler fits: right now, reverse engineering and patching firmware is spread across IDA, hex editors, TunerPro, and assemblers, constantly switching between programs adds complexity. If the compiler pipeline gets stable enough, the entire flow could be automated, write C, compile to HC11 ASM, ground it against human review, and flash it, all in one tool. Add an AI layer with an API key or a local Ollama model constrained to the Delco 445 hardware limits, and the process of generating and validating firmware patches becomes something more than one person can review alone. Different people bring different skills and perspectives, that is how every serious open source project works. The hardware constraints of the real 68HC11 and the Delco 445 board are the guardrails.

This also serves people who want to understand how HP Tuners RTT custom OS works. Real-time tuning into the stock ECU without swapping chips, done by patching RAM, the same concept used on MEMCAL ECUs with NVRAM, but now done through software and the MPVI over the OBD port. Understanding how that works benefits commercial tuners and DIY enthusiasts equally.

The information here is only as accurate as what is publicly available and what has been found using custom-built tools. Other tools that were recommended in the forums do not work the way people claimed.

The signal to noise ratio matters. Having everything mapped out with clear assumptions that are testable and falsifiable is the goal. Once the opcodes, hook points, and address mapping are solid, a significant portion of the ASM patches will work. More mitigation strategies and workarounds will come from testing.

The end goal is this: the part where you have to understand the ECU and how it works is already documented here. Custom OS is the next step. One person alone cannot validate every patch method, it could be done but it would take months and still be just one person's word that it works. This needs people to pull it apart and look for mistakes, every correction makes it stronger. If the documentation is clear enough, other people can test and validate different approaches and share their results. The more people who can understand and contribute, the better.

Tuners can use this information to make their own tools, to understand how commercial tools work, or just to understand how the ECU works and what is possible with it. The point is not to make one tool, it is to make the knowledge available so anyone can make their own or just understand what is going on. This is not made up, it is based on real work that has already been done, just approached differently.

People point toward commercial tools. The point of reverse engineering is to make your own tools, share them, and use them.

The Holden legacy should not die because the knowledge to keep it alive is locked in retired tuners' heads and behind commercial paywalls. These same concepts apply to any ECU. This one just happens to be the hardest to do it on, and the most worth doing.

If a concept is incorrect and someone has hands-on facts to replace it with, put an issue up. Don't just put up issues saying it's AI slop. Every correction with evidence makes this stronger.


