public class LeaseExpiryReminderSchedulable implements Schedulable {
    public void execute(SchedulableContext sc) {
        Date thirtyDays = Date.today().addDays(30);
        Date oneDay = Date.today().addDays(1);

        List<Lease_Agreement__c> leases = [SELECT Tenant__r.Email__c, Property__r.Name, End_Date__c 
                                          FROM Lease_Agreement__c 
                                          WHERE End_Date__c = :thirtyDays OR End_Date__c = :oneDay];

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        for (Lease_Agreement__c l : leases) {
            if (l.Tenant__r.Email__c != null) {
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setToAddresses(new String[] { l.Tenant__r.Email__c });
                mail.setSubject('Lease Renewal Reminder');
                mail.setPlainTextBody('Your lease for ' + l.Property__r.Name + ' expires on ' + l.End_Date__c + '. Contact us to renew.');
                emails.add(mail);
            }
        }
        if (!emails.isEmpty()) Messaging.sendEmail(emails);
    }
}