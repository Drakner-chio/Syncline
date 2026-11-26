# CurseForge banners

Source of the images in `docs/images/`, made the same way as GearShare's and Gatherline's.
Put the fonts (Space Grotesk and Inter, OFL: `npm pack @fontsource-variable/space-grotesk @fontsource-variable/inter`,
the `*-latin-wght-normal.woff2` files) into `fonts/` (not in git), then:

```
python3 docs/banner-source/render.py [path to chrome]
```

renders each `.banner` section at 2x into `docs/images/syncline-N.png` (convert to JPG for CurseForge).

The banners are illustrations in Syncline's look, not screenshots; player names, steps and step
texts in them are made up. The guide names are RestedXP's real ones.
