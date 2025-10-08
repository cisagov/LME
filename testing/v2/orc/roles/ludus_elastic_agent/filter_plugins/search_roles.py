class FilterModule(object):
    @staticmethod
    def search_roles(ludus, search_role):
        if not isinstance(ludus, list): # Ludus must be a list of VM objects
            return None
        else:
            for vm in ludus:
                if vm.get('roles') and isinstance(vm.get('roles'), list):
                    for role in vm.get('roles'):
                        if isinstance(role, str) and search_role in role:
                            return vm
                        elif isinstance(role, dict) and search_role in role.get('name', ''):
                            return vm
        return None

    def filters(self):
        return {
            'search_roles': self.search_roles
        }