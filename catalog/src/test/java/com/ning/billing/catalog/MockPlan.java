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

public class MockPlan extends DefaultPlan {

	public MockPlan(String name, DefaultProduct product, DefaultPlanPhase[] planPhases, DefaultPlanPhase finalPhase, int plansAllowedInBundle) {
		setName(name);
		setProduct(product);
		setFinalPhase(finalPhase);
		setInitialPhases(planPhases);
		setPlansAllowedInBundle(plansAllowedInBundle);
	}
	
	public MockPlan() {
		setName("test-plan");
		setProduct(new MockProduct());
		setFinalPhase(new MockPlanPhase(this));
		setInitialPhases(null);
		setPlansAllowedInBundle(1);
	}

	public MockPlan(MockPlanPhase mockPlanPhase) {
		setName("test-plan");
		setProduct(new MockProduct());
		setFinalPhase(mockPlanPhase);
		setInitialPhases(null);
		setPlansAllowedInBundle(1);
	}


}