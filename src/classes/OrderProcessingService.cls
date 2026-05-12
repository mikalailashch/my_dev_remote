public class OrderProcessingService {

    // Recursion guard — used in after update trigger
    private static Set<Id> processedOrderIds = new Set<Id>();

    // ─── Called from: Order trigger (after update) ────────────────────────────

    public static void handleAfterUpdate(
            List<Order> newOrders,
            Map<Id, Order> oldMap
    ) {
        List<Order> changedOrders = new List<Order>();

        for (Order ord : newOrders) {
            processedOrderIds.add(ord.Id);
            if (ord.Status != oldMap.get(ord.Id).Status) {
                changedOrders.add(ord);
            }
        }

        if (!changedOrders.isEmpty()) {
            processStatusChanges(changedOrders);
        }
    }

    // ─────────────────────────────────────────────────────────────────────────

    private static void processStatusChanges(List<Order> orders) {
        String auditReport    = '';
        List<Task> tasksToCreate = new List<Task>();

        for (Order ord : orders) {

            List<OrderItem> items = [
                    SELECT Id, UnitPrice, Quantity, Product2.ProductCode
                    FROM   OrderItem
                    WHERE  OrderId = :ord.Id
            ];

            Decimal total = 0;
            for (OrderItem item : items) {
                total        += item.UnitPrice * item.Quantity;
                auditReport  += item.Product2.ProductCode
                        + ': ' + item.Quantity + '\n';
            }

            if (ord.Status == 'Activated') {
                notifyERPAsync(ord.Id, ord.AccountId);
                tasksToCreate.add(new Task(
                        Subject  = 'Order Activated: ' + ord.OrderNumber,
                        WhatId   = ord.Id,
                        Status   = 'Not Started',
                        Priority = 'High'
                ));
            }
        }

        if (!tasksToCreate.isEmpty()) {
            insert tasksToCreate;
        }

        pushAuditToExternalSystem(auditReport);
    }

    // ─────────────────────────────────────────────────────────────────────────

    @future(callout=true)
    private static void notifyERPAsync(Id orderId, Id accountId) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:ERP_Integration/orders');
        req.setMethod('POST');
        req.setBody(JSON.serialize(new Map<String, Object>{
                'sf_order_id'   => orderId,
                'sf_account_id' => accountId
        }));

        HttpResponse res = new Http().send(req);

        Map<String, Object> body =
                (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

        String erpId = (String) body.get('erp_order_id');
        upsert new Order(Id = orderId, ERP_Order_Id__c = erpId);
    }

    // ─────────────────────────────────────────────────────────────────────────

    private static void pushAuditToExternalSystem(String payload) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Audit_Service/logs');
        req.setMethod('POST');
        req.setBody(payload);
        new Http().send(req);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Batch: Monthly revenue sync to ERP
    // ─────────────────────────────────────────────────────────────────────────

    public class MonthlyRevenueSyncBatch implements Database.Batchable<SObject> {

        private List<String> errorLog = new List<String>();

        public Database.QueryLocator start(Database.BatchableContext ctx) {
            return Database.getQueryLocator([
                    SELECT Id, TotalAmount, AccountId, OwnerId
                    FROM   Order
                    WHERE  Status = 'Activated'
                    AND    CALENDAR_MONTH(EffectiveDate) = :Date.today().month()
            ]);
        }

        public void execute(Database.BatchableContext ctx, List<Order> scope) {
            for (Order ord : scope) {
                try {
                    notifyERPAsync(ord.Id, ord.AccountId);
                } catch (Exception e) {
                    errorLog.add(ord.Id + ' — ' + e.getMessage());
                }
            }
        }

        public void finish(Database.BatchableContext ctx) {
            if (!errorLog.isEmpty()) {
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setToAddresses(new List<String>{'ops@company.com'});
                mail.setSubject('Monthly ERP Sync Errors');
                mail.setPlainTextBody(String.join(errorLog, '\n'));
                Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // LWC Apex Controllers
    // ─────────────────────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static Order createDraftOrder(Id accountId) {
        Order o = new Order(
                AccountId     = accountId,
                Status        = 'Draft',
                EffectiveDate = Date.today()
        );
        insert o;
        return o;
    }

    @AuraEnabled
    public static List<Order> getActiveOrders(Id accountId) {
        return [
                SELECT Id, TotalAmount, Status, OrderNumber,
                        Account.Name, Account.CreditLimit__c
                FROM   Order
                WHERE  AccountId = :accountId
                AND    Status    = 'Activated'
                ORDER BY CreatedDate DESC
        ];
    }
}


//  Part 2 — JavaScript: OrderDashboard LWC component

import { LightningElement, wire, track } from 'lwc';
import getActiveOrders from '@salesforce/apex/OrderProcessingService.getActiveOrders';
import createDraftOrder from '@salesforce/apex/OrderProcessingService.createDraftOrder';

export default class OrderDashboard extends LightningElement {

@track orders = [];
selectedAccountId;

@wire(getActiveOrders, { accountId: '$selectedAccountId' })
wiredOrders;

// ── Case 1: Is there a problem here? ─────────────────────────────────────

connectedCallback() {
this.pollingInterval = setInterval(() => {
this.refreshData();
}, 5000);
this.loadMeta();
}

// ── Case 2: User saves a new Order. List doesn't update. Why? ────────────

async handleCreate() {
await createDraftOrder({ accountId: this.selectedAccountId });
// expects @wire list to refresh automatically...
}

// ── Case 3: What's the output and why? ───────────────────────────────────

async loadMeta() {
const config    = await fetchConfig();
const templates = await fetchTemplates();
return { config, templates };
}

// ── Case 4: Is there a bug? What happens if Apex throws? ─────────────────

async handleSave() {
const result = await createDraftOrder({ accountId: this.selectedAccountId });
this.showToast('Success', result.Id, 'success');
}

showToast(title, message, variant) {
const evt = new ShowToastEvent({ title, message, variant });
this.dispatchEvent(evt);
}
}



