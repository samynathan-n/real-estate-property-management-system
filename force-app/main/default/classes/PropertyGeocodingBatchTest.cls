@isTest
private class PropertyGeocodingBatchTest {

    // Mock returning a successful Nominatim-style response
    private class SuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('[{"lat":"12.9715987","lon":"77.5945627"}]');
            return res;
        }
    }

    // Mock returning an empty result array (address not found)
    private class NoResultsMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('[]');
            return res;
        }
    }

    // Mock simulating a failed callout (e.g. service down)
    private class FailureMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(503);
            res.setBody('Service Unavailable');
            return res;
        }
    }

    private static Property__c buildProperty(String suffix) {
        Property__c p = new Property__c();
        p.Name = 'Test Property ' + suffix;
        p.Property_Address__Street__s = '1 MG Road';
        p.Property_Address__City__s = 'Bengaluru';
        p.Property_Address__StateCode__s = 'KA';
        p.Property_Address__PostalCode__s = '560001';
        p.Property_Address__CountryCode__s = 'IN';
        p.Type__c = 'Residential';
        p.Furnishing_Status__c = 'Furnished';
        p.Status__c = 'Available';
        p.Rent__c = 25000;
        p.Description__c = 'Test description';
        return p;
    }

    // PropertyTrigger (after insert) automatically enqueues the batch,
    // so tests only need to insert the record inside startTest/stopTest
    // with the mock set beforehand -- no need to call executeBatch directly.

    @isTest
    static void testSuccessfulGeocode() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        Property__c prop = buildProperty('1');

        Test.startTest();
        insert prop;
        Test.stopTest(); // batch enqueued by trigger runs here

        Property__c result = [SELECT Geolocation__Latitude__s, Geolocation__Longitude__s FROM Property__c WHERE Id = :prop.Id];
        System.assertEquals(12.9715987, result.Geolocation__Latitude__s, 'Latitude should be set from mock response');
        System.assertEquals(77.5945627, result.Geolocation__Longitude__s, 'Longitude should be set from mock response');
    }

    @isTest
    static void testNoResultsFound() {
        Test.setMock(HttpCalloutMock.class, new NoResultsMock());
        Property__c prop = buildProperty('2');

        Test.startTest();
        insert prop;
        Test.stopTest();

        Property__c result = [SELECT Geolocation__Latitude__s FROM Property__c WHERE Id = :prop.Id];
        System.assertEquals(null, result.Geolocation__Latitude__s, 'Latitude should remain null when no results are found');
    }

    @isTest
    static void testCalloutFailureIsHandledGracefully() {
        Test.setMock(HttpCalloutMock.class, new FailureMock());
        Property__c prop = buildProperty('3');

        Test.startTest();
        insert prop;
        Test.stopTest();

        Property__c result = [SELECT Geolocation__Latitude__s FROM Property__c WHERE Id = :prop.Id];
        System.assertEquals(null, result.Geolocation__Latitude__s, 'Latitude should remain null on callout failure, no exception should propagate');
    }

    @isTest
    static void testBulkGeocode() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        List<Property__c> props = new List<Property__c>();
        for (Integer i = 0; i < 50; i++) {
            props.add(buildProperty(String.valueOf(i)));
        }

        Test.startTest();
        insert props;
        Test.stopTest();

        Set<Id> ids = new Map<Id, Property__c>(props).keySet();
        List<Property__c> results = [SELECT Geolocation__Latitude__s FROM Property__c WHERE Id IN :ids];
        for (Property__c p : results) {
            System.assertEquals(12.9715987, p.Geolocation__Latitude__s, 'Every bulk record should be geocoded');
        }
    }
}
