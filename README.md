# PetOMatic

PetOMatic is Wildstar addon to make the summoning of vanity pets easier. It is designed to work like the mount button. It provides a button on the UI that allows you to select a pet from your unlocked vanity pets. Once selected, you can summon and dismiss the pet by clicking the button. 

**Current Features**
* Autosummoning of pet after resurrecting from death. This may be toggled through the Options window or with the command `/pom auto`
  * Autosummoning is suspend while in a Raid
* Ability to move the pet button
  * Option to reset button to default position
* Customize the number of pets displayed in the list at once
* Saves last selected pet on logout/reload ui
* Configurable through an options window
  * Options window can be opened through the Interfaces menu or with the command `/pom config`
* List of pets automatically updates when new pet is unlocked
* List of pets opens above button by default, but will move list below the button if the position of the button would cause the list to open past the top of the screen
* The pet button may be hidden from the UI either. This may be toggled through the Options window or with the command `/pom hide`
