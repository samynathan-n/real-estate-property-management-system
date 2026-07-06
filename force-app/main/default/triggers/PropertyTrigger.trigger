/**
 * Trigger: PropertyTrigger
 * Purpose: On insert of Property__c, kick off a single Batch Apex job
 *          (scoped only to the newly inserted records) to geocode
 *          each property's address via the Nominatim API.
 *
 * Design note: batching all new Ids into ONE batch job (rather than
 * one job per record) keeps us well within the 5 concurrent batch
 * job limit even on bulk inserts.
 */
trigger PropertyTrigger on Property__c (after insert) {

    if (Trigger.isAfter && Trigger.isInsert) {
        Set<Id> newPropertyIds = Trigger.newMap.keySet();

        // Batch size of 1 keeps callouts spaced out, respecting
        // Nominatim's 1 request/second usage policy.
        Database.executeBatch(new PropertyGeocodingBatch(newPropertyIds), 1);
    }
}
