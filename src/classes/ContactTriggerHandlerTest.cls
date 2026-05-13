@isTest
private class ContactTriggerHandlerTest {

    @TestSetup
    static void setupTestData() {
        // Create test accounts with different industries
        List<Account> accounts = new List<Account>{
            new Account(
                Name = 'Tech Company',
                Industry = 'Technology',
                BillingState = 'CA'
            ),
            new Account(
                Name = 'Finance Company',
                Industry = 'Finance',
                BillingState = 'NY'
            ),
            new Account(
                Name = 'Retail Company',
                Industry = 'Retail',
                BillingState = 'TX'
            )
        };
        insert accounts;
    }

    @isTest
    static void testBeforeInsert_TechnologyAccount() {
        // Given: A contact for a Technology account
        Account techAccount = [SELECT Id FROM Account WHERE Industry = 'Technology' LIMIT 1];

        Contact con = new Contact(
            FirstName = 'John',
            LastName = 'Doe',
            AccountId = techAccount.Id,
            Email = 'john.doe@tech.com'
        );

        // When: Insert the contact
        Test.startTest();
        insert con;
        Test.stopTest();

        // Then: Contact Level__c should be set to 'Primary'
        Contact insertedContact = [SELECT Id, Level__c FROM Contact WHERE Id = :con.Id];
        System.assertEquals('Primary', insertedContact.Level__c, 'Level should be set to Primary for Technology accounts');
    }

    @isTest
    static void testBeforeInsert_NonTechnologyAccount() {
        // Given: A contact for a non-Technology account
        Account financeAccount = [SELECT Id FROM Account WHERE Industry = 'Finance' LIMIT 1];

        Contact con = new Contact(
            FirstName = 'Jane',
            LastName = 'Smith',
            AccountId = financeAccount.Id,
            Email = 'jane.smith@finance.com'
        );

        // When: Insert the contact
        Test.startTest();
        insert con;
        Test.stopTest();

        // Then: Contact Level__c should NOT be set to 'Primary'
        Contact insertedContact = [SELECT Id, Level__c FROM Contact WHERE Id = :con.Id];
        System.assertNotEquals('Primary', insertedContact.Level__c, 'Level should not be Primary for non-Technology accounts');
    }

    @isTest
    static void testBeforeInsert_NoAccount() {
        // Given: A contact without an account
        Contact con = new Contact(
            FirstName = 'Bob',
            LastName = 'Jones',
            Email = 'bob.jones@email.com'
        );

        // When: Insert the contact
        Test.startTest();
        insert con;
        Test.stopTest();

        // Then: No error should occur
        Contact insertedContact = [SELECT Id, Level__c FROM Contact WHERE Id = :con.Id];
        System.assertNotEquals(null, insertedContact.Id, 'Contact should be inserted successfully');
    }

    @isTest
    static void testAfterInsert_TaskCreation() {
        // Given: A contact ready to insert
        Account techAccount = [SELECT Id FROM Account WHERE Industry = 'Technology' LIMIT 1];

        Contact con = new Contact(
            FirstName = 'Alice',
            LastName = 'Williams',
            AccountId = techAccount.Id,
            Email = 'alice@tech.com'
        );

        // When: Insert the contact with HTTP mock
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        Test.startTest();
        insert con;
        Test.stopTest();

        // Then: A follow-up task should be created
        List<Task> tasks = [SELECT Id, Subject, WhoId, Status, Priority FROM Task WHERE WhoId = :con.Id];
        System.assertEquals(1, tasks.size(), 'One task should be created');
        System.assertEquals('Follow up with Alice', tasks[0].Subject, 'Task subject should match');
        System.assertEquals('Not Started', tasks[0].Status, 'Task status should be Not Started');
        System.assertEquals('Normal', tasks[0].Priority, 'Task priority should be Normal');
    }

    @isTest
    static void testAfterInsert_MultipleContacts() {
        // Given: Multiple contacts
        Account techAccount = [SELECT Id FROM Account WHERE Industry = 'Technology' LIMIT 1];

        List<Contact> contacts = new List<Contact>{
            new Contact(FirstName = 'Contact1', LastName = 'Test1', AccountId = techAccount.Id),
            new Contact(FirstName = 'Contact2', LastName = 'Test2', AccountId = techAccount.Id),
            new Contact(FirstName = 'Contact3', LastName = 'Test3', AccountId = techAccount.Id)
        };

        // When: Insert multiple contacts
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        Test.startTest();
        insert contacts;
        Test.stopTest();

        // Then: Tasks should be created for all contacts
        List<Task> tasks = [SELECT Id FROM Task WHERE WhoId IN :contacts];
        System.assertEquals(3, tasks.size(), 'Three tasks should be created for three contacts');
    }

    @isTest
    static void testAfterUpdate_AccountUpdate() {
        // Given: An existing contact
        Account techAccount = [SELECT Id FROM Account WHERE Industry = 'Technology' LIMIT 1];

        Contact con = new Contact(
            FirstName = 'Update',
            LastName = 'Test',
            AccountId = techAccount.Id,
            Email = 'update@test.com'
        );

        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        insert con;

        // When: Update the contact
        Test.startTest();
        con.Email = 'newemail@test.com';
        update con;
        Test.stopTest();

        // Then: The update should complete without errors
        Contact updatedContact = [SELECT Id, Email FROM Contact WHERE Id = :con.Id];
        System.assertEquals('newemail@test.com', updatedContact.Email, 'Email should be updated');
    }

    @isTest
    static void testHandleTrigger_AllParameters() {
        // Given: Prepare trigger context data
        Account techAccount = [SELECT Id FROM Account WHERE Industry = 'Technology' LIMIT 1];

        Contact con = new Contact(
            FirstName = 'Trigger',
            LastName = 'Test',
            AccountId = techAccount.Id
        );

        // When: Call handleTrigger directly
        ContactTriggerHandler handler = new ContactTriggerHandler();

        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        Test.startTest();

        // Test before insert
        handler.handleTrigger(
            new List<Contact>{con},
            null,
            null,
            null,
            true,
            false,
            true,
            false,
            false
        );

        insert con;

        // Test after insert
        Map<Id, Contact> newMap = new Map<Id, Contact>{con.Id => con};
        handler.handleTrigger(
            new List<Contact>{con},
            null,
            newMap,
            null,
            false,
            true,
            true,
            false,
            false
        );

        // Test after update
        Contact oldCon = con.clone(true);
        con.Email = 'changed@test.com';
        Map<Id, Contact> oldMap = new Map<Id, Contact>{oldCon.Id => oldCon};

        handler.handleTrigger(
            new List<Contact>{con},
            new List<Contact>{oldCon},
            newMap,
            oldMap,
            false,
            true,
            false,
            true,
            false
        );

        Test.stopTest();

        // Then: All trigger operations should complete successfully
        System.assertNotEquals(null, con.Id, 'Contact should be processed successfully');
    }

    @isTest
    static void testUpdateContacts_BulkOperation() {
        // Given: Multiple contacts for technology accounts
        List<Account> techAccounts = new List<Account>();
        for (Integer i = 0; i < 5; i++) {
            techAccounts.add(new Account(
                Name = 'Tech ' + i,
                Industry = 'Technology'
            ));
        }
        insert techAccounts;

        List<Contact> contacts = new List<Contact>();
        for (Account acc : techAccounts) {
            contacts.add(new Contact(
                FirstName = 'Bulk',
                LastName = 'Test' + acc.Name,
                AccountId = acc.Id
            ));
        }

        // When: Insert bulk contacts
        Test.startTest();
        insert contacts;
        Test.stopTest();

        // Then: All contacts should have Level__c set to Primary
        List<Contact> insertedContacts = [SELECT Id, Level__c FROM Contact WHERE Id IN :contacts];
        for (Contact c : insertedContacts) {
            System.assertEquals('Primary', c.Level__c, 'All contacts should have Primary level');
        }
    }

    @isTest
    static void testSendContactNotification_Success() {
        // Given: A contact to trigger notification
        Account techAccount = [SELECT Id FROM Account WHERE Industry = 'Technology' LIMIT 1];

        Contact con = new Contact(
            FirstName = 'Notification',
            LastName = 'Test',
            AccountId = techAccount.Id
        );

        // When: Insert contact with successful HTTP mock
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        Test.startTest();
        insert con;
        Test.stopTest();

        // Then: Contact should be inserted successfully (HTTP callout mocked)
        System.assertNotEquals(null, con.Id, 'Contact should be inserted with notification sent');
    }

    // Mock HTTP Response for testing callouts
    private class MockHttpResponseGenerator implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            // Verify the request
            System.assertEquals('POST', req.getMethod(), 'Should be POST method');
            System.assertEquals('https://api.example.com/contacts', req.getEndpoint(), 'Endpoint should match');

            // Create a fake response
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"status":"success"}');
            res.setStatusCode(200);
            return res;
        }
    }

    @isTest
    static void testSendContactNotification_Failure() {
        // Given: A contact to trigger notification
        Account techAccount = [SELECT Id FROM Account WHERE Industry = 'Technology' LIMIT 1];

        Contact con = new Contact(
            FirstName = 'Failed',
            LastName = 'Notification',
            AccountId = techAccount.Id
        );

        // When: Insert contact with failed HTTP mock
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGeneratorFailure());
        Test.startTest();
        insert con;
        Test.stopTest();

        // Then: Contact should still be inserted (notification failure doesn't block)
        System.assertNotEquals(null, con.Id, 'Contact should be inserted even if notification fails');
    }

    // Mock HTTP Response for failure scenario
    private class MockHttpResponseGeneratorFailure implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"status":"error"}');
            res.setStatusCode(500);
            return res;
        }
    }
}

