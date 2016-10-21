type 'a finset = Finset of 'a list
let list_from_finset (Finset l) = l
let finset_from_list l = (Finset l)
