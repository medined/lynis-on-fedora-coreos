ansible -i inventory -u core fcos -m gather_facts > facts.txt
more facts.txt
