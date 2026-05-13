trigger EventTrigger on Event (after insert, after update, after delete, after undelete) {
    EventTriggerHandler handler = new EventTriggerHandler();

    handler.handleTrigger(
        Trigger.new,
        Trigger.old,
        Trigger.newMap,
        Trigger.oldMap,
        Trigger.isBefore,
        Trigger.isAfter,
        Trigger.isInsert,
        Trigger.isUpdate,
        Trigger.isDelete,
        Trigger.isUndelete
    );
}

