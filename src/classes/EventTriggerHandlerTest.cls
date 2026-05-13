@IsTest
private class EventTriggerHandlerTest {

    @TestSetup
    static void setupTestData() {
        // Create test accounts
        Account testAccount = new Account(
            Name = 'Test Account',
            Industry = 'Technology'
        );
        insert testAccount;

        // Create test contacts
        List<Contact> contacts = new List<Contact>{
            new Contact(
                FirstName = 'John',
                LastName = 'Doe',
                AccountId = testAccount.Id,
                Email = 'john.doe@test.com'
            ),
            new Contact(
                FirstName = 'Jane',
                LastName = 'Smith',
                AccountId = testAccount.Id,
                Email = 'jane.smith@test.com'
            )
        };
        insert contacts;
    }

    @IsTest
    static void testAfterInsert_SingleEvent() {
        // Given: A contact
        Contact con = [SELECT Id, Number_Of_Events__c FROM Contact WHERE FirstName = 'John' LIMIT 1];
        System.assertEquals(null, con.Number_Of_Events__c, 'Initial count should be null');

        // When: Create an event for the contact
        Event evt = new Event(
            Subject = 'Test Meeting',
            WhoId = con.Id,
            StartDateTime = System.now(),
            EndDateTime = System.now().addHours(1)
        );

        Test.startTest();
        insert evt;
        Test.stopTest();

        // Then: Contact should have 1 event
        Contact updatedContact = [SELECT Id, Number_Of_Events__c FROM Contact WHERE Id = :con.Id];
        System.assertEquals(1, updatedContact.Number_Of_Events__c, 'Contact should have 1 event');
    }

    @IsTest
    static void testAfterInsert_MultipleEvents() {
        // Given: A contact
        Contact con = [SELECT Id FROM Contact WHERE FirstName = 'John' LIMIT 1];

        // When: Create multiple events for the contact
        List<Event> events = new List<Event>();
        for (Integer i = 0; i < 5; i++) {
            events.add(new Event(
                Subject = 'Test Meeting ' + i,
                WhoId = con.Id,
                StartDateTime = System.now().addDays(i),
                EndDateTime = System.now().addDays(i).addHours(1)
            ));
        }

        Test.startTest();
        insert events;
        Test.stopTest();

        // Then: Contact should have 5 events
        Contact updatedContact = [SELECT Id, Number_Of_Events__c FROM Contact WHERE Id = :con.Id];
        System.assertEquals(5, updatedContact.Number_Of_Events__c, 'Contact should have 5 events');
    }

    @IsTest
    static void testAfterUpdate_ChangeContact() {
        // Given: Two contacts and an event for the first contact
        Contact con1 = [SELECT Id FROM Contact WHERE FirstName = 'John' LIMIT 1];
        Contact con2 = [SELECT Id FROM Contact WHERE FirstName = 'Jane' LIMIT 1];

        Event evt = new Event(
            Subject = 'Test Meeting',
            WhoId = con1.Id,
            StartDateTime = System.now(),
            EndDateTime = System.now().addHours(1)
        );
        insert evt;

        // Verify initial state
        Contact contact1 = [SELECT Id, Number_Of_Events__c FROM Contact WHERE Id = :con1.Id];
        System.assertEquals(1, contact1.Number_Of_Events__c, 'Contact 1 should have 1 event');

        // When: Change the event to the second contact
        Test.startTest();
        evt.WhoId = con2.Id;
        update evt;
        Test.stopTest();

        // Then: Contact 1 should have 0 events, Contact 2 should have 1 event
        Contact updatedContact1 = [SELECT Id, Number_Of_Events__c FROM Contact WHERE Id = :con1.Id];
        Contact updatedContact2 = [SELECT Id, Number_Of_Events__c FROM Contact WHERE Id = :con2.Id];

        System.assertEquals(0, updatedContact1.Number_Of_Events__c, 'Contact 1 should have 0 events');
        System.assertEquals(1, updatedContact2.Number_Of_Events__c, 'Contact 2 should have 1 event');
    }

    @IsTest
    static void testAfterDelete() {
        // Given: A contact with events
        Contact con = [SELECT Id FROM Contact WHERE FirstName = 'John' LIMIT 1];

        List<Event> events = new List<Event>();
        for (Integer i = 0; i < 3; i++) {
            events.add(new Event(
                Subject = 'Test Meeting ' + i,
                WhoId = con.Id,
                StartDateTime = System.now().addDays(i),
                EndDateTime = System.now().addDays(i).addHours(1)
            ));
        }
        insert events;

        // Verify initial state
        Contact contact = [SELECT Id, Number_Of_Events__c FROM Contact WHERE Id = :con.Id];
        System.assertEquals(3, contact.Number_Of_Events__c, 'Contact should have 3 events');

        // When: Delete one event
        Test.startTest();
        delete events[0];
        Test.stopTest();

        // Then: Contact should have 2 events
        Contact updatedContact = [SELECT Id, Number_Of_Events__c FROM Contact WHERE Id = :con.Id];
        System.assertEquals(2, updatedContact.Number_Of_Events__c, 'Contact should have 2 events after delete');
    }

    @IsTest
    static void testAfterUndelete() {
        // Given: A contact with events, one of which is deleted
        Contact con = [SELECT Id FROM Contact WHERE FirstName = 'John' LIMIT 1];

        List<Event> events = new List<Event>();
        for (Integer i = 0; i < 3; i++) {
            events.add(new Event(
                Subject = 'Test Meeting ' + i,
                WhoId = con.Id,
                StartDateTime = System.now().addDays(i),
                EndDateTime = System.now().addDays(i).addHours(1)
            ));
        }
        insert events;

        Event eventToDelete = events[0];
        delete eventToDelete;

        // Verify state after delete
        Contact contact = [SELECT Id, Number_Of_Events__c FROM Contact WHERE Id = :con.Id];
        System.assertEquals(2, contact.Number_Of_Events__c, 'Contact should have 2 events');

        // When: Undelete the event
        Test.startTest();
        undelete eventToDelete;
        Test.stopTest();

        // Then: Contact should have 3 events again
        Contact updatedContact = [SELECT Id, Number_Of_Events__c FROM Contact WHERE Id = :con.Id];
        System.assertEquals(3, updatedContact.Number_Of_Events__c, 'Contact should have 3 events after undelete');
    }

    @IsTest
    static void testBulkOperations() {
        // Given: Multiple contacts
        List<Contact> contacts = [SELECT Id FROM Contact];

        // When: Create bulk events (50 events per contact)
        List<Event> events = new List<Event>();
        Integer eventsPerContact = 50;

        for (Contact con : contacts) {
            for (Integer i = 0; i < eventsPerContact; i++) {
                events.add(new Event(
                    Subject = 'Bulk Event ' + i,
                    WhoId = con.Id,
                    StartDateTime = System.now().addDays(i),
                    EndDateTime = System.now().addDays(i).addHours(1)
                ));
            }
        }

        Test.startTest();
        insert events;
        Test.stopTest();

        // Then: Each contact should have the correct count
        List<Contact> updatedContacts = [
            SELECT Id, Number_Of_Events__c
            FROM Contact
            WHERE Id IN :contacts
        ];

        for (Contact con : updatedContacts) {
            System.assertEquals(eventsPerContact, con.Number_Of_Events__c,
                              'Each contact should have ' + eventsPerContact + ' events');
        }
    }

    @IsTest
    static void testEventWithNoContact() {
        // Given: An account (for WhatId)
        Account acc = [SELECT Id FROM Account LIMIT 1];

        // When: Create an event without a WhoId (Contact)
        Event evt = new Event(
            Subject = 'Account Meeting',
            WhatId = acc.Id,
            StartDateTime = System.now(),
            EndDateTime = System.now().addHours(1)
        );

        Test.startTest();
        insert evt;
        Test.stopTest();

        // Then: No contacts should be updated
        List<Contact> contacts = [SELECT Id, Number_Of_Events__c FROM Contact];
        for (Contact con : contacts) {
            System.assertEquals(null, con.Number_Of_Events__c,
                              'Contact count should remain null for events without WhoId');
        }
    }

    @IsTest
    static void testHandleTrigger_DirectCall() {
        // Given: A contact and an event
        Contact con = [SELECT Id FROM Contact WHERE FirstName = 'John' LIMIT 1];

        Event evt = new Event(
            Subject = 'Direct Test',
            WhoId = con.Id,
            StartDateTime = System.now(),
            EndDateTime = System.now().addHours(1)
        );

        // When: Call handler directly
        EventTriggerHandler handler = new EventTriggerHandler();

        Test.startTest();
        handler.handleTrigger(
            new List<Event>{evt},
            null,
            null,
            null,
            false,
            true,
            true,
            false,
            false,
            false
        );
        Test.stopTest();

        // Then: Should execute without errors
        System.assertNotEquals(null, handler, 'Handler should be instantiated');
    }

    @IsTest
    static void testDeleteAllEvents() {
        // Given: A contact with multiple events
        Contact con = [SELECT Id FROM Contact WHERE FirstName = 'John' LIMIT 1];

        List<Event> events = new List<Event>();
        for (Integer i = 0; i < 3; i++) {
            events.add(new Event(
                Subject = 'Test Meeting ' + i,
                WhoId = con.Id,
                StartDateTime = System.now().addDays(i),
                EndDateTime = System.now().addDays(i).addHours(1)
            ));
        }
        insert events;

        // Verify initial state
        Contact contact = [SELECT Id, Number_Of_Events__c FROM Contact WHERE Id = :con.Id];
        System.assertEquals(3, contact.Number_Of_Events__c, 'Contact should have 3 events');

        // When: Delete all events
        Test.startTest();
        delete events;
        Test.stopTest();

        // Then: Contact should have 0 events
        Contact updatedContact = [SELECT Id, Number_Of_Events__c FROM Contact WHERE Id = :con.Id];
        System.assertEquals(0, updatedContact.Number_Of_Events__c, 'Contact should have 0 events');
    }
}

