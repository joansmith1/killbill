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

package com.ning.billing.catalog;

import com.ning.billing.catalog.api.BillingPeriod;
import com.ning.billing.catalog.api.PhaseType;
import com.ning.billing.catalog.api.ProductCategory;
import com.ning.billing.catalog.rules.*;

import java.util.Date;

public class MockCatalog extends StandaloneCatalog {
	private static final String[] PRODUCT_NAMES = new String[]{ "TestProduct1", "TestProduct2", "TestProduct3"};
	
	public MockCatalog() {
		setEffectiveDate(new Date());
		populateProducts();
		populateRules();
		populatePlans();
		populatePriceLists();
	}
	
	public void populateRules(){
		setPlanRules(new PlanRules());
	}

	public void setRules( 
			CaseChangePlanPolicy[] caseChangePlanPolicy,
			CaseChangePlanAlignment[] caseChangePlanAlignment,
			CaseCancelPolicy[] caseCancelPolicy,
			CaseCreateAlignment[] caseCreateAlignment
			){
		
	}

	public void populateProducts() {
		String[] names = getProductNames();
		DefaultProduct[] products = new DefaultProduct[names.length];
		for(int i = 0; i < names.length; i++) {
			products[i] = new DefaultProduct(names[i], ProductCategory.BASE);
		}
		setProducts(products);
	}
	
	public void populatePlans() {
		DefaultProduct[] products = getProducts();
		DefaultPlan[] plans = new DefaultPlan[products.length];
		for(int i = 0; i < products.length; i++) {
			DefaultPlanPhase phase = new DefaultPlanPhase().setPhaseType(PhaseType.EVERGREEN).setBillingPeriod(BillingPeriod.MONTHLY).setReccuringPrice(new DefaultInternationalPrice());
			plans[i] = new MockPlan().setName(products[i].getName().toLowerCase() + "-plan").setProduct(products[i]).setFinalPhase(phase);
		}
		setPlans(plans);
	}

	public void populatePriceLists() {
		DefaultPlan[] plans = getPlans();
		
		DefaultPriceList[] priceList = new DefaultPriceList[plans.length - 1];
		for(int i = 1; i < plans.length; i++) {
			priceList[i-1] = new DefaultPriceList(new DefaultPlan[]{plans[i]},plans[i].getName()+ "-pl");
		}
		
		DefaultPriceListSet set = new DefaultPriceListSet(new PriceListDefault(new DefaultPlan[]{plans[0]}),priceList);
		setPriceLists(set);
	}
	
	public String[] getProductNames() {
		return PRODUCT_NAMES;
	}


	
}