## Changelog 1.5.0-beta.6

Beta Release

### Adds
* Added PTR Support (API 11)
* When a pet is selected from the pet list, it will automatically be summoned if another pet is currently summoned. 
  * If mounted, in a vehicle, or in a taxi, selected pet will be summoned once no longer mounted.
* Added new slash commands. All options have corresponding slash commands.
  * Type /pom for a list of slash commands.
* Random pet capability - Click the die on the button to summon a random pet. Can also be triggered with the command /pom random
* Option to center button on screen. This should help users of ForgeUI find and reposition the button easier. The command /pom center will also center the button

### Updates
* Options window style changed to conform to native UI window style.
* Tooltip style changed to match native action bar tooltips.

### Fixes
* Button will no longer become enabled if Max List Size slider is changed in Options window when no character has no unlocked pets.
* Complete rework of slider-handling logic
* Code to identified button has been moved and store new position has been corrected.

### Known Issues
* *No Known Issues*
