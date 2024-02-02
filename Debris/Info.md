#Debris
A efficient caching Library

## Functions

####getFolder(Name:`string`,MaxTime:`number`,Destroy:`(any)->()`): `Constructor`
Returns the Debris object with the name or creates a new Debris Object with the attached params.

`Name`: Name of the object
`MaxTime`: How long should the child should stay cached. Default 60s.
`Destroy`: a callback fired when the child is being destroyed

## Methods
####getName(): `string`
Gets the name of the Debris object 

####getSize(): `number`
Returns how many children in the object. Warning this method is O(n).

####clearAll()
Clears and remove all the children in the object.

####get(key:`any`): `any`
Returns the value stored in key and refresh the destroy time. 

####rawGet(key:`any`) `any`
Returns the value stored in the key and does NOT refresh the destroy time.

####add(key:`any`,value:`any`)
Adds the value to the Object.

####remove(key`any`)
Removes the child


