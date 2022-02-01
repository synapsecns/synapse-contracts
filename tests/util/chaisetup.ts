import {waffleChai} from "@ethereum-waffle/chai"
import chaiAsPromised from "chai-as-promised";
import chaiThings from "chai-things";

import * as chai from "chai";

chai
    .use(chaiThings)
    .use(waffleChai)
    .use(chaiAsPromised);

export default chai.expect;
