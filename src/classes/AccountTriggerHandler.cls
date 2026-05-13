public class AccountTriggerHandler {

    public void handleTrigger(List<Account> newAccounts, List<Account> oldAccounts,
            Map<Id, Account> newMap, Map<Id, Account> oldMap,
            Boolean isBefore, Boolean isAfter,
            Boolean isInsert, Boolean isUpdate, Boolean isDelete) {

        if (isBefore && isInsert) {
            beforeInsert(newAccounts);
        }

        if (isBefore && isUpdate) {
            beforeUpdate(newAccounts, oldMap);
        }

        if (isAfter && isInsert) {
            afterInsert(newAccounts);
        }

        if (isAfter && isUpdate) {
            afterUpdate(newAccounts, oldMap);
        }
    }

    // Set default values on new accounts
    private void beforeInsert(List<Account> newAccounts) {
        for (Account acc : newAccounts) {
            // Set default rating if not provided
            if (String.isBlank(acc.Rating)) {
                acc.Rating = 'Warm';
            }

            // Auto-populate description based on industry
            if (String.isNotBlank(acc.Industry) && String.isBlank(acc.Description)) {
                acc.Description = 'Company in ' + acc.Industry + ' industry';
            }

            // Set default ownership for specific industries
            if (acc.Industry == 'Technology' || acc.Industry == 'Finance') {
                acc.Type = 'Prospect';
            }
        }
    }

    // Update account fields when certain criteria change
    private void beforeUpdate(List<Account> newAccounts, Map<Id, Account> oldMap) {
        for (Account acc : newAccounts) {
            Account oldAccount = oldMap.get(acc.Id);

            // If Annual Revenue increased significantly, update rating
            if (acc.AnnualRevenue != null && oldAccount.AnnualRevenue != null) {
                if (acc.AnnualRevenue > oldAccount.AnnualRevenue * 1.5) {
                    acc.Rating = 'Hot';
                }
            }

            // Update description when industry changes
            if (acc.Industry != oldAccount.Industry && String.isNotBlank(acc.Industry)) {
                acc.Description = 'Company in ' + acc.Industry + ' industry - Updated on ' +
                                 System.now().format('yyyy-MM-dd');
            }
        }
    }

    // Create default contact for new accounts
    private void afterInsert(List<Account> newAccounts) {
        List<Contact> contactsToInsert = new List<Contact>();

        for (Account acc : newAccounts) {
            // Create a placeholder contact for accounts without contacts
            if (acc.Type == 'Prospect') {
                Contact newContact = new Contact(
                    FirstName = 'Default',
                    LastName = acc.Name + ' Contact',
                    AccountId = acc.Id,
                    Email = 'contact@' + acc.Name.replaceAll('[^a-zA-Z0-9]', '').toLowerCase() + '.com'
                );
                contactsToInsert.add(newContact);
            }
        }

        if (!contactsToInsert.isEmpty()) {
            insert contactsToInsert;
        }
    }

    // Update related contacts when account rating changes
    private void afterUpdate(List<Account> newAccounts, Map<Id, Account> oldMap) {
        Set<Id> hotAccountIds = new Set<Id>();

        for (Account acc : newAccounts) {
            Account oldAccount = oldMap.get(acc.Id);

            // Track accounts that became "Hot"
            if (acc.Rating == 'Hot' && oldAccount.Rating != 'Hot') {
                hotAccountIds.add(acc.Id);
            }
        }

        // Update contacts for hot accounts
        if (!hotAccountIds.isEmpty()) {
            List<Contact> contactsToUpdate = [
                SELECT Id, Description
                FROM Contact
                WHERE AccountId IN :hotAccountIds
                LIMIT 200
            ];

            for (Contact con : contactsToUpdate) {
                con.Description = 'High priority - Account is Hot rated';
            }

            if (!contactsToUpdate.isEmpty()) {
                update contactsToUpdate;
            }
        }
    }
}

