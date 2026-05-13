public class EventTriggerHandler {

    public void handleTrigger(List<Event> newEvents, List<Event> oldEvents,
            Map<Id, Event> newMap, Map<Id, Event> oldMap,
            Boolean isBefore, Boolean isAfter,
            Boolean isInsert, Boolean isUpdate, Boolean isDelete, Boolean isUndelete) {

        if (isAfter && isInsert) {
            afterInsert(newEvents);
        }

        if (isAfter && isUpdate) {
            afterUpdate(newEvents, oldMap);
        }

        if (isAfter && isDelete) {
            afterDelete(oldEvents);
        }

        if (isAfter && isUndelete) {
            afterUndelete(newEvents);
        }
    }

    // When events are inserted, update contact event counts
    private void afterInsert(List<Event> newEvents) {
        Set<Id> contactIds = getContactIds(newEvents);
        if (!contactIds.isEmpty()) {
            updateContactEventCounts(contactIds);
        }
    }

    // When events are updated and contact changes, update both old and new contacts
    private void afterUpdate(List<Event> newEvents, Map<Id, Event> oldMap) {
        Set<Id> contactIds = new Set<Id>();

        for (Event evt : newEvents) {
            Event oldEvent = oldMap.get(evt.Id);

            // If WhoId (Contact) changed, update both old and new contact
            if (evt.WhoId != oldEvent.WhoId) {
                if (isContactId(evt.WhoId)) {
                    contactIds.add(evt.WhoId);
                }
                if (isContactId(oldEvent.WhoId)) {
                    contactIds.add(oldEvent.WhoId);
                }
            } else if (isContactId(evt.WhoId)) {
                // Even if WhoId didn't change, still update in case other fields changed
                contactIds.add(evt.WhoId);
            }
        }

        if (!contactIds.isEmpty()) {
            updateContactEventCounts(contactIds);
        }
    }

    // When events are deleted, update contact event counts
    private void afterDelete(List<Event> oldEvents) {
        Set<Id> contactIds = getContactIds(oldEvents);
        if (!contactIds.isEmpty()) {
            updateContactEventCounts(contactIds);
        }
    }

    // When events are undeleted, update contact event counts
    private void afterUndelete(List<Event> newEvents) {
        Set<Id> contactIds = getContactIds(newEvents);
        if (!contactIds.isEmpty()) {
            updateContactEventCounts(contactIds);
        }
    }

    // Extract Contact IDs from events
    private Set<Id> getContactIds(List<Event> events) {
        Set<Id> contactIds = new Set<Id>();

        for (Event evt : events) {
            if (isContactId(evt.WhoId)) {
                contactIds.add(evt.WhoId);
            }
        }

        return contactIds;
    }

    // Check if the ID is a Contact ID (starts with '003')
    private Boolean isContactId(Id whoId) {
        return whoId != null && String.valueOf(whoId).startsWith('003');
    }

    // Update the Number_Of_Events__c field on contacts
    private void updateContactEventCounts(Set<Id> contactIds) {
        // Query to get event counts per contact
        Map<Id, Integer> contactEventCounts = new Map<Id, Integer>();

        for (AggregateResult ar : [
            SELECT WhoId, COUNT(Id) eventCount
            FROM Event
            WHERE WhoId IN :contactIds
            AND WhoId != null
            GROUP BY WhoId
        ]) {
            Id contactId = (Id)ar.get('WhoId');
            Integer count = (Integer)ar.get('eventCount');
            contactEventCounts.put(contactId, count);
        }

        // Get contacts and update their event counts
        List<Contact> contactsToUpdate = [
            SELECT Id, Number_Of_Events__c
            FROM Contact
            WHERE Id IN :contactIds
        ];

        for (Contact con : contactsToUpdate) {
            // Set count to 0 if no events found
            con.Number_Of_Events__c = contactEventCounts.containsKey(con.Id)
                ? contactEventCounts.get(con.Id)
                : 0;
        }

        if (!contactsToUpdate.isEmpty()) {
            update contactsToUpdate;
        }
    }
}

