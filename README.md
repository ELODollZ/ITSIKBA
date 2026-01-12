# ITSIKBA
Afslutende for IT Sikkerheds

Samlingen af kodes.

Injections er koden som bruges til demo af Red-Team.
Koden hhv:
- Opretter brugere, med og uden sudo afhængig af opsætning
- Kan opryde efter spor, slette historik dynamisk
- kan Manipulere dynamisk log filer, I.E. hvis det køres igennem ssh, kan du sætte startTidspunkt før man ssh'ed ind og efter man har ssh'ed ud, så vil den fjerne logs i de tids intervaller.
Det antages man kender bruger information og det er på samme netværk (umildbart kan det ikke gå rundt om NAT)
