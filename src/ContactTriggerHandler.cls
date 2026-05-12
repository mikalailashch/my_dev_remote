public class ContactTriggerHandler {

    public void handleTrigger(List<Contact> newContacts, List<Contact> oldContacts,
            Map<Id, Contact> newMap, Map<Id, Contact> oldMap,
            Boolean isBefore, Boolean isAfter,
            Boolean isInsert, Boolean isUpdate, Boolean isDelete) {

        if (isBefore && isInsert) {
            beforeInsert(newContacts);
        }

        if (isAfter && isInsert) {
            afterInsert(newContacts);
        }

        if (isAfter && isUpdate) {
            afterUpdate(newContacts, oldMap);
        }

    }
//    _____________________________________________________________

    private void beforeInsert(List<Contact> newContacts) {
        List<Contact> contactsToUpdate = new List<Contact>();
        for (Contact con : newContacts) {
            if (con.AccountId != null) {
                List<Account> accounts = [
                        SELECT Id, Name, Industry, AnnualRevenue
                        FROM Account
                        WHERE Id = :con.AccountId
                ];
                if (!accounts.isEmpty()) {
                    if (accounts[0].Industry == 'Technology') {
                        contactsToUpdate.add(con);
                    }
                }
            }
            updateContacts(contactsToUpdate);
        }
    }

    private void updateContacts(List<Contact> contactsToUpdate) {
        for (Contact contact : contactsToUpdate) {
            contact.Level__c = 'Primary';
        }

        // check DML limits before performing update
        if (contactsToUpdate.size() < 3000) {
            update contactsToUpdate;
        } else {
            contactsToUpdate[0].addError('Too many contacts to update');
        }
    }

    //    _____________________________________________________________

    // Also used in the LWC controller
    public void afterInsert(List<Contact> newContacts) {

        List<Task> tasksToInsert = new List<Task>();

        // Purpose: Create follow-up tasks for each new contact
        for (Contact con : newContacts) {
            Task t = new Task(
                    Subject = 'Follow up with ' + con.FirstName,
                    WhoId = con.Id,
                    Status = 'Not Started',
                    Priority = 'Normal'
            );
            tasksToInsert.add(t);
        }

        insert tasksToInsert;

        // Purpose: Send notification to external system
        sendContactNotification(newContacts[0].Id);

        // Purpose: Enqueue queueable jobs to perform additional processing asynchronously
        System.enqueueJob(new MyQueueableClass());
        System.enqueueJob(new MyParentQueueableClass());
    }

    private static void sendContactNotification(Id contactId) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://api.example.com/contacts');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(contactId));

        Http http = new Http();
        HttpResponse res = http.send(req);                  //You have uncommitted work pending. Please commit or rollback before calling out

        if (res.getStatusCode() == 200) {
            System.debug('Notification sent successfully');
        }
    }

    //    _____________________________________________________________

    private static final String HOME_ACCOUNT_ID = '001000000000000';

    private void afterUpdate(List<Contact> newContacts, Map<Id, Contact> oldMap) {

        List<Contact> allContacts = [
                SELECT Id, AccountId
                FROM Contact
                LIMIT 50000
        ];

        List<Account> accounts = [
                SELECT Id
                FROM Account
                WHERE Id IN: allContacts
                LIMIT 50000
        ];

        List<Account> filteredAccounts = new List<Account>();
        for (Account account : accounts) {
            if (account.Id != HOME_ACCOUNT_ID) {
                filteredAccounts.add(account);
            }
        }

        for (Account account : filteredAccounts) {
            if (account.BillingState != null) {
                List<Task> tasks = new List<Task>();
                if (account.CreatedDate == System.now()) {
                    Task newTask;
                    if (account.Active__c == true) {
                        newTask = new Task(
                                Subject = 'Contact Update Alert',
                                AccountId = account.Id,
                                Status = 'New',
                                Priority = 'High'
                        );
                        tasks.add(newTask);
                    }
                }
                insert tasks;
            }
        }
    }
}
 