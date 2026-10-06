import { Router, type IRouter } from "express";
import healthRouter from "./health";
import foodbridgeRouter from "./foodbridge";

const router: IRouter = Router();

router.use(healthRouter);
router.use(foodbridgeRouter);

export default router;
