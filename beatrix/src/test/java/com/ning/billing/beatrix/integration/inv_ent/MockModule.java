/*
 * Copyright 2010-2011 Ning, Inc.
 *
 * Ning licenses this file to you under the Apache License, version 2.0
 * (the "License"); you may not use this file except in compliance with the
 * License.  You may obtain a copy of the License at:
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
 * WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the
 * License for the specific language governing permissions and limitations
 * under the License.
 */

package com.ning.billing.beatrix.integration.inv_ent;

import static org.testng.Assert.assertNotNull;

import java.io.IOException;
import java.net.URL;
import java.util.Set;

import org.skife.config.ConfigurationObjectFactory;
import org.skife.jdbi.v2.DBI;
import org.skife.jdbi.v2.IDBI;

import com.google.common.collect.ImmutableSet;
import com.google.inject.AbstractModule;
import com.google.inject.Inject;
import com.google.inject.Injector;
import com.ning.billing.account.glue.AccountModule;
import com.ning.billing.beatrix.lifecycle.DefaultLifecycle;
import com.ning.billing.beatrix.lifecycle.Lifecycle;
import com.ning.billing.catalog.api.CatalogService;
import com.ning.billing.catalog.glue.CatalogModule;
import com.ning.billing.dbi.DBIProvider;
import com.ning.billing.dbi.DbiConfig;
import com.ning.billing.entitlement.api.EntitlementService;
import com.ning.billing.entitlement.glue.EntitlementModule;
import com.ning.billing.invoice.api.InvoiceService;
import com.ning.billing.invoice.glue.InvoiceModule;
import com.ning.billing.lifecycle.KillbillService;
import com.ning.billing.util.clock.Clock;
import com.ning.billing.util.clock.ClockMock;
import com.ning.billing.util.eventbus.BusService;
import com.ning.billing.util.glue.BusModule;
import com.ning.billing.util.glue.NotificationQueueModule;


public class MockModule extends AbstractModule {

    @Override
    protected void configure() {

        loadSystemPropertiesFromClasspath("/resource.properties");

        bind(Clock.class).to(ClockMock.class).asEagerSingleton();
        bind(ClockMock.class).asEagerSingleton();
        bind(Lifecycle.class).to(SubsetDefaultLifecycle.class).asEagerSingleton();
        bind(IDBI.class).toProvider(DBIProvider.class).asEagerSingleton();
        final DbiConfig config = new ConfigurationObjectFactory(System.getProperties()).build(DbiConfig.class);
        bind(DbiConfig.class).toInstance(config);
        install(new BusModule());
        install(new NotificationQueueModule());
        install(new AccountModule());
        install(new CatalogModule());
        install(new EntitlementModule());
        install(new InvoiceModule());
    }


    private static void loadSystemPropertiesFromClasspath(final String resource) {
        final URL url = TestBasic.class.getResource(resource);
        assertNotNull(url);
        try {
            System.getProperties().load( url.openStream() );
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
    }

    private final static class SubsetDefaultLifecycle extends DefaultLifecycle {


        @Inject
        public SubsetDefaultLifecycle(Injector injector) {
            super(injector);
        }

        @Override
        protected Set<? extends KillbillService> findServices() {
            ImmutableSet<? extends KillbillService> services = new ImmutableSet.Builder<KillbillService>()
                            .add(injector.getInstance(BusService.class))
                            .add(injector.getInstance(CatalogService.class))
                            .add(injector.getInstance(EntitlementService.class))
                            .add(injector.getInstance(InvoiceService.class))
                            .build();
            return services;
        }
    }
}