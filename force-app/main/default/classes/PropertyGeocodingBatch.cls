public class PropertyGeocodingBatch implements Database.Batchable<SObject>, Database.AllowsCallouts {

    private Set<Id> propertyIds;

    private static Map<String, String> stateCodeToLabel;
    private static Map<String, String> countryCodeToLabel;

    public PropertyGeocodingBatch(Set<Id> propertyIds) {
        this.propertyIds = propertyIds;
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {

        System.debug(LoggingLevel.INFO,
            '===== PropertyGeocodingBatch START =====');

        return Database.getQueryLocator([
            SELECT Id,
                   Property_Address__Street__s,
                   Property_Address__City__s,
                   Property_Address__StateCode__s,
                   Property_Address__PostalCode__s,
                   Property_Address__CountryCode__s
            FROM Property__c
            WHERE Id IN :propertyIds
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Property__c> scope) {

        System.debug(LoggingLevel.INFO,
            '===== PropertyGeocodingBatch EXECUTE START =====');

        System.debug(LoggingLevel.INFO,
            'Scope Size : ' + scope.size());

        if(stateCodeToLabel == null){
            stateCodeToLabel =
                buildCodeToLabelMap('Property_Address__StateCode__s');
        }

        if(countryCodeToLabel == null){
            countryCodeToLabel =
                buildCodeToLabelMap('Property_Address__CountryCode__s');
        }

        List<Property__c> toUpdate = new List<Property__c>();

        for(Property__c prop : scope){

            System.debug(LoggingLevel.INFO,
                'Processing Property : ' + prop.Id);

            // Uses the NEW q= endpoint (defined in Part 2)
            String endpoint = buildEndpoint(prop);

            System.debug(LoggingLevel.INFO,
                'Generated Endpoint : ' + endpoint);

            if(String.isBlank(endpoint)){

                System.debug(LoggingLevel.WARN,
                    'Skipping Property because endpoint is blank.');

                continue;
            }

            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('GET');

            req.setHeader(
                'User-Agent',
                'RealEstatePMS-SalesforceApp/1.0 (task-round-submission)'
            );

            req.setTimeout(10000);

            try{

                System.debug(LoggingLevel.INFO,
                    'Sending HTTP Request...');

                HttpResponse res = new Http().send(req);

                System.debug(LoggingLevel.INFO,
                    'Status Code : ' + res.getStatusCode());

                System.debug(LoggingLevel.INFO,
                    'Response Body : ' + res.getBody());

                if(res.getStatusCode() == 200){

                    List<Object> results =
                        (List<Object>)JSON.deserializeUntyped(res.getBody());

                    if(!results.isEmpty()){

                        Map<String,Object> place =
                            (Map<String,Object>)results[0];

                        Decimal lat =
                            Decimal.valueOf((String)place.get('lat'));

                        Decimal lon =
                            Decimal.valueOf((String)place.get('lon'));

                        System.debug(LoggingLevel.INFO,
                            'Latitude : ' + lat);

                        System.debug(LoggingLevel.INFO,
                            'Longitude : ' + lon);

                        Property__c updateRecord = new Property__c(
                            Id = prop.Id,
                            Geolocation__Latitude__s = lat,
                            Geolocation__Longitude__s = lon
                        );

                        toUpdate.add(updateRecord);

                    }else{

                        System.debug(LoggingLevel.WARN,
                            'No results returned from Nominatim.');

                    }

                }else{

                    System.debug(LoggingLevel.ERROR,
                        'Callout Failed.');

                    System.debug(LoggingLevel.ERROR,
                        'Status : ' + res.getStatusCode());

                    System.debug(LoggingLevel.ERROR,
                        res.getBody());

                }

            }catch(Exception ex){

                System.debug(LoggingLevel.ERROR,
                    'Exception occurred.');

                System.debug(LoggingLevel.ERROR,
                    ex.getMessage());

                System.debug(LoggingLevel.ERROR,
                    ex.getStackTraceString());

            }

        }

        if(!toUpdate.isEmpty()){

            System.debug(LoggingLevel.INFO,
                'Updating ' + toUpdate.size() + ' records.');

            Database.SaveResult[] saveResults =
                Database.update(toUpdate, false);

            for(Database.SaveResult sr : saveResults){

                if(sr.isSuccess()){

                    System.debug(LoggingLevel.INFO,
                        'Successfully Updated : ' + sr.getId());

                }else{

                    for(Database.Error err : sr.getErrors()){

                        System.debug(LoggingLevel.ERROR,
                            err.getStatusCode() + ' - ' + err.getMessage());

                    }

                }

            }

        }

        System.debug(LoggingLevel.INFO,
            '===== PropertyGeocodingBatch EXECUTE END =====');

    }

        public void finish(Database.BatchableContext bc) {

        System.debug(
            LoggingLevel.INFO,
            '===== PropertyGeocodingBatch FINISH ====='
        );

    }

    /**
     * Builds a map of Picklist Code -> Label.
     * Example:
     * KA -> Karnataka
     * IN -> India
     */
    private static Map<String, String> buildCodeToLabelMap(String fieldApiName) {

        Map<String,String> result = new Map<String,String>();

        Schema.DescribeFieldResult fieldDescribe =
            Property__c.SObjectType.getDescribe()
                .fields.getMap()
                .get(fieldApiName)
                .getDescribe();

        for(Schema.PicklistEntry entry :
            fieldDescribe.getPicklistValues()){

            if(entry.isActive()){

                result.put(
                    entry.getValue(),
                    entry.getLabel()
                );

            }

        }

        return result;

    }

    /**
     * Builds the Nominatim endpoint using the q parameter.
     *
     * Example:
     * https://nominatim.openstreetmap.org/search?format=jsonv2&q=627452,Tirunelveli,India
     */
    private String buildEndpoint(Property__c prop){

        List<String> addressParts = new List<String>();

        // Postal Code
        if(String.isNotBlank(prop.Property_Address__PostalCode__s)){
            addressParts.add(prop.Property_Address__PostalCode__s);
        }

        // City
        if(String.isNotBlank(prop.Property_Address__City__s)){
            addressParts.add(prop.Property_Address__City__s);
        }

        // Country
        if(String.isNotBlank(prop.Property_Address__CountryCode__s)){

            String countryName =
                countryCodeToLabel.containsKey(
                    prop.Property_Address__CountryCode__s
                )
                ? countryCodeToLabel.get(
                    prop.Property_Address__CountryCode__s
                )
                : prop.Property_Address__CountryCode__s;

            addressParts.add(countryName);
        }

        if(addressParts.isEmpty()){

            System.debug(
                LoggingLevel.WARN,
                'No address available to build endpoint.'
            );

            return null;
        }

        String query = String.join(addressParts, ',');

        System.debug(
            LoggingLevel.INFO,
            'Search Query : ' + query
        );

        String endpoint =
            'https://nominatim.openstreetmap.org/search?format=jsonv2&limit=1&q=' +
            EncodingUtil.urlEncode(query, 'UTF-8');

        System.debug(
            LoggingLevel.INFO,
            'Generated Endpoint : ' + endpoint
        );

        return endpoint;

    }

}