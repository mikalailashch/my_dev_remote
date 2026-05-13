@IsTest
private class AccountTriggerHandlerTest {

    @TestSetup
    static void setupTestData() {
        // This will be called once before all test methods
        List<Account> accounts = new List<Account>{
            new Account(
                Name = 'Test Tech Company',
                Industry = 'Technology',
                AnnualRevenue = 1000000
            ),
            new Account(
                Name = 'Test Finance Company',
                Industry = 'Finance',
                AnnualRevenue = 2000000
            ),
            new Account(
                Name = 'Test Retail Company',
                Industry = 'Retail',
                AnnualRevenue = 500000,
                Rating = 'Cold'
            )
        };
        insert accounts;
    }

    @IsTest
    static void testBeforeInsert_DefaultRating() {
        // Given: An account without a rating
        Account acc = new Account(
            Name = 'New Account',
            Industry = 'Healthcare'
        );

        // When: Insert the account
        Test.startTest();
        insert acc;
        Test.stopTest();

        // Then: Rating should be set to 'Warm'
        Account insertedAccount = [SELECT Id, Rating, Description FROM Account WHERE Id = :acc.Id];
        System.assertEquals('Warm', insertedAccount.Rating, 'Default rating should be Warm');
        System.assertEquals('Company in Healthcare industry', insertedAccount.Description,
                          'Description should be auto-populated');
    }

    @IsTest
    static void testBeforeInsert_TechnologyIndustry() {
        // Given: An account in Technology industry
        Account acc = new Account(
            Name = 'Tech Startup',
            Industry = 'Technology'
        );

        // When: Insert the account
        Test.startTest();
        insert acc;
        Test.stopTest();

        // Then: Type should be set to 'Prospect'
        Account insertedAccount = [SELECT Id, Type, Rating FROM Account WHERE Id = :acc.Id];
        System.assertEquals('Prospect', insertedAccount.Type, 'Type should be Prospect for Technology');
        System.assertEquals('Warm', insertedAccount.Rating, 'Rating should be Warm');
    }

    @IsTest
    static void testBeforeInsert_FinanceIndustry() {
        // Given: An account in Finance industry
        Account acc = new Account(
            Name = 'Finance Corp',
            Industry = 'Finance'
        );

        // When: Insert the account
        Test.startTest();
        insert acc;
        Test.stopTest();

        // Then: Type should be set to 'Prospect'
        Account insertedAccount = [SELECT Id, Type FROM Account WHERE Id = :acc.Id];
        System.assertEquals('Prospect', insertedAccount.Type, 'Type should be Prospect for Finance');
    }

    @IsTest
    static void testBeforeUpdate_RevenueIncrease() {
        // Given: An existing account
        Account acc = [SELECT Id, AnnualRevenue, Rating FROM Account WHERE Name = 'Test Tech Company' LIMIT 1];

        // When: Increase revenue significantly (more than 1.5x)
        Test.startTest();
        acc.AnnualRevenue = 2000000; // Double the original 1M
        update acc;
        Test.stopTest();

        // Then: Rating should be updated to 'Hot'
        Account updatedAccount = [SELECT Id, Rating FROM Account WHERE Id = :acc.Id];
        System.assertEquals('Hot', updatedAccount.Rating, 'Rating should be Hot after significant revenue increase');
    }

    @IsTest
    static void testBeforeUpdate_IndustryChange() {
        // Given: An existing account
        Account acc = [SELECT Id, Industry, Description FROM Account WHERE Name = 'Test Retail Company' LIMIT 1];
        String oldIndustry = acc.Industry;

        // When: Change the industry
        Test.startTest();
        acc.Industry = 'Manufacturing';
        update acc;
        Test.stopTest();

        // Then: Description should be updated with new industry and date
        Account updatedAccount = [SELECT Id, Description FROM Account WHERE Id = :acc.Id];
        System.assert(updatedAccount.Description.contains('Manufacturing'),
                     'Description should contain new industry');
        System.assert(updatedAccount.Description.contains('Updated on'),
                     'Description should contain update date');
    }

    @IsTest
    static void testAfterInsert_CreateDefaultContact() {
        // Given: A new prospect account
        Account acc = new Account(
            Name = 'Prospect Account',
            Industry = 'Technology', // This will make it Type = 'Prospect'
            Type = 'Prospect'
        );

        // When: Insert the account
        Test.startTest();
        insert acc;
        Test.stopTest();

        // Then: A default contact should be created
        List<Contact> contacts = [
            SELECT Id, FirstName, LastName, AccountId, Email
            FROM Contact
            WHERE AccountId = :acc.Id
        ];

        System.assertEquals(1, contacts.size(), 'One contact should be created');
        System.assertEquals('Default', contacts[0].FirstName, 'First name should be Default');
        System.assert(contacts[0].LastName.contains(acc.Name), 'Last name should contain account name');
    }

    @IsTest
    static void testAfterInsert_NoContactForNonProspect() {
        // Given: A non-prospect account
        Account acc = new Account(
            Name = 'Customer Account',
            Industry = 'Retail',
            Type = 'Customer'
        );

        // When: Insert the account
        Test.startTest();
        insert acc;
        Test.stopTest();

        // Then: No contact should be created
        List<Contact> contacts = [
            SELECT Id
            FROM Contact
            WHERE AccountId = :acc.Id
        ];

        System.assertEquals(0, contacts.size(), 'No contact should be created for non-prospect');
    }

    @IsTest
    static void testAfterUpdate_UpdateContactsForHotRating() {
        // Given: An account with existing contacts
        Account acc = [SELECT Id, Rating FROM Account WHERE Name = 'Test Finance Company' LIMIT 1];

        // Create some contacts
        List<Contact> contacts = new List<Contact>{
            new Contact(FirstName = 'John', LastName = 'Doe', AccountId = acc.Id),
            new Contact(FirstName = 'Jane', LastName = 'Smith', AccountId = acc.Id)
        };
        insert contacts;

        // When: Change rating to 'Hot'
        Test.startTest();
        acc.Rating = 'Hot';
        update acc;
        Test.stopTest();

        // Then: Contacts should have updated description
        List<Contact> updatedContacts = [
            SELECT Id, Description
            FROM Contact
            WHERE AccountId = :acc.Id
        ];

        System.assertEquals(3, updatedContacts.size(), 'Both contacts should exist');
        for (Contact con : updatedContacts) {
            System.assertEquals('High priority - Account is Hot rated', con.Description,
                              'Contact description should be updated');
        }
    }

    @IsTest
    static void testAfterUpdate_NoUpdateWhenRatingStaysHot() {
        // Given: An account already rated 'Hot'
        Account acc = [SELECT Id, Rating FROM Account WHERE Name = 'Test Tech Company' LIMIT 1];
        acc.Rating = 'Hot';
        update acc;

        Contact con = new Contact(FirstName = 'Test', LastName = 'User', AccountId = acc.Id);
        insert con;

        // When: Update account but keep rating as 'Hot'
        Test.startTest();
        acc.Phone = '555-1234';
        update acc;
        Test.stopTest();

        // Then: Contact description should not be updated
        Contact updatedContact = [SELECT Id, Description FROM Contact WHERE Id = :con.Id];
        System.assertEquals(null, updatedContact.Description,
                          'Description should not be updated when rating stays Hot');
    }

    @IsTest
    static void testBulkInsert() {
        // Given: Multiple accounts
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < 200; i++) {
            accounts.add(new Account(
                Name = 'Bulk Account ' + i,
                Industry = 'Technology',
                AnnualRevenue = 100000 * i
            ));
        }

        // When: Bulk insert
        Test.startTest();
        insert accounts;
        Test.stopTest();

        // Then: All accounts should be inserted with defaults
        List<Account> insertedAccounts = [
            SELECT Id, Rating, Type, Description
            FROM Account
            WHERE Name LIKE 'Bulk Account%'
        ];

        System.assertEquals(200, insertedAccounts.size(), '200 accounts should be inserted');
        for (Account acc : insertedAccounts) {
            System.assertEquals('Warm', acc.Rating, 'All should have Warm rating');
            System.assertEquals('Prospect', acc.Type, 'All Technology accounts should be Prospect');
        }
    }

    @IsTest
    static void testHandleTrigger_DirectCall() {
        // Given: An account
        Account acc = new Account(
            Name = 'Direct Test',
            Industry = 'Energy'
        );

        // When: Call handler directly
        AccountTriggerHandler handler = new AccountTriggerHandler();

        Test.startTest();
        handler.handleTrigger(
            new List<Account>{acc},
            null,
            null,
            null,
            true,
            false,
            true,
            false,
            false
        );
        Test.stopTest();

        // Then: Before insert logic should be applied
        System.assertEquals('Warm', acc.Rating, 'Rating should be set');
        System.assertEquals('Company in Energy industry', acc.Description, 'Description should be set');
    }
}

