// GENERATED FILE -- do not hand-edit.
// Produced by ml/export_posture_model_to_arduino.py from posture_model.joblib
// Classes: ['lying', 'standing']
// Feature order (must match capturePostureWindow() in furfeel_sensor.ino
// exactly): ['accel_x_mean', 'accel_x_std', 'accel_x_min', 'accel_x_max', 'accel_y_mean', 'accel_y_std', 'accel_y_min', 'accel_y_max', 'accel_z_mean', 'accel_z_std', 'accel_z_min', 'accel_z_max', 'gyro_x_mean', 'gyro_x_std', 'gyro_x_min', 'gyro_x_max', 'gyro_y_mean', 'gyro_y_std', 'gyro_y_min', 'gyro_y_max', 'gyro_z_mean', 'gyro_z_std', 'gyro_z_min', 'gyro_z_max', 'accel_mag_mean', 'accel_mag_std']

#pragma once
#include <cstdarg>
namespace Eloquent {
    namespace ML {
        namespace Port {
            class RandomForest {
                public:
                    /**
                    * Predict class for features vector
                    */
                    int predict(float *x) {
                        uint8_t votes[2] = { 0 };
                        // tree #1
                        if (x[6] <= -0.015850000083446503) {
                            if (x[25] <= 0.02516635973006487) {
                                if (x[0] <= 0.12284750118851662) {
                                    votes[1] += 1;
                                }

                                else {
                                    votes[0] += 1;
                                }
                            }

                            else {
                                votes[0] += 1;
                            }
                        }

                        else {
                            if (x[8] <= -1.0060524940490723) {
                                votes[1] += 1;
                            }

                            else {
                                votes[0] += 1;
                            }
                        }

                        // tree #2
                        if (x[8] <= -1.0049225091934204) {
                            if (x[6] <= -0.09400000050663948) {
                                votes[0] += 1;
                            }

                            else {
                                votes[1] += 1;
                            }
                        }

                        else {
                            if (x[2] <= -0.22629999741911888) {
                                votes[1] += 1;
                            }

                            else {
                                votes[0] += 1;
                            }
                        }

                        // tree #3
                        if (x[3] <= 0.1262499950826168) {
                            votes[1] += 1;
                        }

                        else {
                            if (x[13] <= 2.3047061562538147) {
                                votes[0] += 1;
                            }

                            else {
                                if (x[2] <= -0.05909999739378691) {
                                    votes[0] += 1;
                                }

                                else {
                                    votes[1] += 1;
                                }
                            }
                        }

                        // tree #4
                        if (x[6] <= -0.015850000083446503) {
                            if (x[3] <= 0.1279500015079975) {
                                votes[1] += 1;
                            }

                            else {
                                if (x[15] <= 10.37594985961914) {
                                    votes[0] += 1;
                                }

                                else {
                                    votes[1] += 1;
                                }
                            }
                        }

                        else {
                            if (x[4] <= -0.009455000050365925) {
                                votes[1] += 1;
                            }

                            else {
                                votes[0] += 1;
                            }
                        }

                        // tree #5
                        if (x[10] <= -1.010949969291687) {
                            if (x[1] <= 0.0025846168864518404) {
                                if (x[6] <= -0.013650000095367432) {
                                    if (x[5] <= 0.0036209425888955593) {
                                        votes[1] += 1;
                                    }

                                    else {
                                        votes[0] += 1;
                                    }
                                }

                                else {
                                    votes[0] += 1;
                                }
                            }

                            else {
                                if (x[8] <= -1.0053250193595886) {
                                    if (x[23] <= 40.10010051727295) {
                                        votes[1] += 1;
                                    }

                                    else {
                                        votes[0] += 1;
                                    }
                                }

                                else {
                                    if (x[4] <= -0.013250000076368451) {
                                        votes[1] += 1;
                                    }

                                    else {
                                        votes[0] += 1;
                                    }
                                }
                            }
                        }

                        else {
                            votes[0] += 1;
                        }

                        // tree #6
                        if (x[2] <= 0.11789999902248383) {
                            if (x[7] <= 0.038349999114871025) {
                                votes[1] += 1;
                            }

                            else {
                                if (x[3] <= 0.2761000022292137) {
                                    votes[1] += 1;
                                }

                                else {
                                    votes[0] += 1;
                                }
                            }
                        }

                        else {
                            votes[0] += 1;
                        }

                        // tree #7
                        if (x[6] <= -0.015850000083446503) {
                            if (x[8] <= -1.0037450194358826) {
                                if (x[7] <= 0.025399999227374792) {
                                    votes[1] += 1;
                                }

                                else {
                                    if (x[6] <= -0.09400000050663948) {
                                        votes[0] += 1;
                                    }

                                    else {
                                        votes[1] += 1;
                                    }
                                }
                            }

                            else {
                                if (x[13] <= 2.428477391600609) {
                                    votes[0] += 1;
                                }

                                else {
                                    votes[1] += 1;
                                }
                            }
                        }

                        else {
                            votes[0] += 1;
                        }

                        // tree #8
                        if (x[6] <= -0.015850000083446503) {
                            if (x[4] <= -0.010369999799877405) {
                                votes[1] += 1;
                            }

                            else {
                                if (x[20] <= -0.3448474854230881) {
                                    votes[1] += 1;
                                }

                                else {
                                    votes[0] += 1;
                                }
                            }
                        }

                        else {
                            if (x[0] <= 0.11626499518752098) {
                                votes[1] += 1;
                            }

                            else {
                                votes[0] += 1;
                            }
                        }

                        // tree #9
                        if (x[4] <= -0.012042499613016844) {
                            votes[1] += 1;
                        }

                        else {
                            votes[0] += 1;
                        }

                        // tree #10
                        if (x[24] <= 1.0118348002433777) {
                            if (x[0] <= 0.11273249611258507) {
                                votes[1] += 1;
                            }

                            else {
                                votes[0] += 1;
                            }
                        }

                        else {
                            if (x[3] <= 0.12889999523758888) {
                                votes[1] += 1;
                            }

                            else {
                                if (x[11] <= -0.9553499817848206) {
                                    votes[0] += 1;
                                }

                                else {
                                    votes[1] += 1;
                                }
                            }
                        }

                        // tree #11
                        if (x[4] <= -0.010369999799877405) {
                            votes[1] += 1;
                        }

                        else {
                            votes[0] += 1;
                        }

                        // tree #12
                        if (x[2] <= 0.1164500005543232) {
                            if (x[6] <= -0.09400000050663948) {
                                if (x[12] <= 4.34418249130249) {
                                    votes[1] += 1;
                                }

                                else {
                                    votes[0] += 1;
                                }
                            }

                            else {
                                votes[1] += 1;
                            }
                        }

                        else {
                            votes[0] += 1;
                        }

                        // tree #13
                        if (x[2] <= 0.1164500005543232) {
                            if (x[10] <= -1.1811500191688538) {
                                votes[0] += 1;
                            }

                            else {
                                votes[1] += 1;
                            }
                        }

                        else {
                            votes[0] += 1;
                        }

                        // tree #14
                        if (x[7] <= -0.0048500001430511475) {
                            votes[1] += 1;
                        }

                        else {
                            if (x[4] <= -0.01648499956354499) {
                                votes[1] += 1;
                            }

                            else {
                                votes[0] += 1;
                            }
                        }

                        // tree #15
                        if (x[2] <= 0.11625000089406967) {
                            if (x[25] <= 0.02633018884807825) {
                                votes[1] += 1;
                            }

                            else {
                                votes[0] += 1;
                            }
                        }

                        else {
                            votes[0] += 1;
                        }

                        // tree #16
                        if (x[4] <= -0.010369999799877405) {
                            votes[1] += 1;
                        }

                        else {
                            if (x[20] <= -0.3707899823784828) {
                                votes[1] += 1;
                            }

                            else {
                                votes[0] += 1;
                            }
                        }

                        // tree #17
                        if (x[3] <= 0.12599999830126762) {
                            votes[1] += 1;
                        }

                        else {
                            if (x[0] <= 0.10637999698519707) {
                                votes[1] += 1;
                            }

                            else {
                                votes[0] += 1;
                            }
                        }

                        // tree #18
                        if (x[4] <= -0.01034749997779727) {
                            votes[1] += 1;
                        }

                        else {
                            if (x[20] <= -0.3936774879693985) {
                                votes[1] += 1;
                            }

                            else {
                                votes[0] += 1;
                            }
                        }

                        // tree #19
                        if (x[7] <= -0.004850000026635826) {
                            votes[1] += 1;
                        }

                        else {
                            if (x[13] <= 2.3047061562538147) {
                                votes[0] += 1;
                            }

                            else {
                                if (x[23] <= 40.10010051727295) {
                                    votes[1] += 1;
                                }

                                else {
                                    votes[0] += 1;
                                }
                            }
                        }

                        // tree #20
                        if (x[4] <= -0.01198749989271164) {
                            votes[1] += 1;
                        }

                        else {
                            if (x[23] <= 17.761200189590454) {
                                votes[0] += 1;
                            }

                            else {
                                if (x[5] <= 0.08237199299037457) {
                                    votes[1] += 1;
                                }

                                else {
                                    votes[0] += 1;
                                }
                            }
                        }

                        // tree #21
                        if (x[24] <= 1.011827826499939) {
                            if (x[3] <= 0.12550000101327896) {
                                votes[1] += 1;
                            }

                            else {
                                votes[0] += 1;
                            }
                        }

                        else {
                            if (x[0] <= 0.12319999560713768) {
                                if (x[18] <= -7.8125) {
                                    votes[0] += 1;
                                }

                                else {
                                    votes[1] += 1;
                                }
                            }

                            else {
                                votes[0] += 1;
                            }
                        }

                        // tree #22
                        if (x[8] <= -1.005025029182434) {
                            if (x[1] <= 0.02922828309237957) {
                                votes[1] += 1;
                            }

                            else {
                                votes[0] += 1;
                            }
                        }

                        else {
                            votes[0] += 1;
                        }

                        // tree #23
                        if (x[2] <= 0.11789999902248383) {
                            if (x[3] <= 0.1999499909579754) {
                                votes[1] += 1;
                            }

                            else {
                                votes[0] += 1;
                            }
                        }

                        else {
                            votes[0] += 1;
                        }

                        // tree #24
                        if (x[11] <= -0.9982500076293945) {
                            if (x[0] <= 0.12329499796032906) {
                                votes[1] += 1;
                            }

                            else {
                                votes[0] += 1;
                            }
                        }

                        else {
                            if (x[10] <= -1.0129500031471252) {
                                if (x[6] <= -0.015149999875575304) {
                                    if (x[16] <= 0.3845224678516388) {
                                        votes[0] += 1;
                                    }

                                    else {
                                        votes[1] += 1;
                                    }
                                }

                                else {
                                    votes[0] += 1;
                                }
                            }

                            else {
                                if (x[8] <= -1.0053799748420715) {
                                    votes[1] += 1;
                                }

                                else {
                                    votes[0] += 1;
                                }
                            }
                        }

                        // tree #25
                        if (x[12] <= 4.3792724609375) {
                            if (x[7] <= -0.004400000092573464) {
                                votes[1] += 1;
                            }

                            else {
                                if (x[19] <= 13.42770004272461) {
                                    votes[0] += 1;
                                }

                                else {
                                    votes[1] += 1;
                                }
                            }
                        }

                        else {
                            if (x[20] <= -0.019832500256597996) {
                                if (x[0] <= 0.11751749739050865) {
                                    votes[1] += 1;
                                }

                                else {
                                    votes[0] += 1;
                                }
                            }

                            else {
                                if (x[11] <= -0.9980499744415283) {
                                    votes[1] += 1;
                                }

                                else {
                                    votes[0] += 1;
                                }
                            }
                        }

                        // tree #26
                        if (x[3] <= 0.1262499950826168) {
                            votes[1] += 1;
                        }

                        else {
                            if (x[19] <= 11.32200002670288) {
                                votes[0] += 1;
                            }

                            else {
                                votes[1] += 1;
                            }
                        }

                        // tree #27
                        if (x[15] <= 4.608150005340576) {
                            if (x[7] <= -0.004650000133551657) {
                                votes[1] += 1;
                            }

                            else {
                                votes[0] += 1;
                            }
                        }

                        else {
                            if (x[2] <= 0.11600000038743019) {
                                if (x[7] <= 0.038349999114871025) {
                                    votes[1] += 1;
                                }

                                else {
                                    if (x[19] <= 7.04954981803894) {
                                        votes[1] += 1;
                                    }

                                    else {
                                        votes[0] += 1;
                                    }
                                }
                            }

                            else {
                                votes[0] += 1;
                            }
                        }

                        // tree #28
                        if (x[3] <= 0.12599999830126762) {
                            votes[1] += 1;
                        }

                        else {
                            if (x[0] <= 0.11742249503731728) {
                                votes[1] += 1;
                            }

                            else {
                                votes[0] += 1;
                            }
                        }

                        // tree #29
                        if (x[12] <= 4.37927508354187) {
                            if (x[3] <= 0.12769999727606773) {
                                votes[1] += 1;
                            }

                            else {
                                if (x[8] <= -1.0059975385665894) {
                                    votes[1] += 1;
                                }

                                else {
                                    votes[0] += 1;
                                }
                            }
                        }

                        else {
                            if (x[6] <= -0.016850000247359276) {
                                if (x[2] <= 0.1091499999165535) {
                                    votes[1] += 1;
                                }

                                else {
                                    votes[0] += 1;
                                }
                            }

                            else {
                                votes[0] += 1;
                            }
                        }

                        // tree #30
                        if (x[8] <= -1.0047749876976013) {
                            if (x[25] <= 0.04700625129044056) {
                                votes[1] += 1;
                            }

                            else {
                                votes[0] += 1;
                            }
                        }

                        else {
                            if (x[16] <= 1.663207471370697) {
                                votes[0] += 1;
                            }

                            else {
                                votes[1] += 1;
                            }
                        }

                        // tree #31
                        if (x[7] <= -0.004850000026635826) {
                            votes[1] += 1;
                        }

                        else {
                            if (x[2] <= 0.04125000070780516) {
                                if (x[19] <= 7.04954981803894) {
                                    votes[1] += 1;
                                }

                                else {
                                    votes[0] += 1;
                                }
                            }

                            else {
                                votes[0] += 1;
                            }
                        }

                        // tree #32
                        if (x[7] <= -0.005100000067614019) {
                            votes[1] += 1;
                        }

                        else {
                            if (x[13] <= 2.3047061562538147) {
                                votes[0] += 1;
                            }

                            else {
                                if (x[24] <= 1.034015953540802) {
                                    votes[1] += 1;
                                }

                                else {
                                    votes[0] += 1;
                                }
                            }
                        }

                        // tree #33
                        if (x[2] <= 0.1164500005543232) {
                            if (x[20] <= -1.1581449806690216) {
                                votes[0] += 1;
                            }

                            else {
                                votes[1] += 1;
                            }
                        }

                        else {
                            votes[0] += 1;
                        }

                        // tree #34
                        if (x[16] <= 1.1596599817276) {
                            if (x[5] <= 0.0024584316415712237) {
                                if (x[3] <= 0.13064999505877495) {
                                    votes[1] += 1;
                                }

                                else {
                                    votes[0] += 1;
                                }
                            }

                            else {
                                if (x[20] <= -0.03662250004708767) {
                                    if (x[10] <= -1.0124500393867493) {
                                        if (x[0] <= 0.12252499908208847) {
                                            votes[1] += 1;
                                        }

                                        else {
                                            votes[0] += 1;
                                        }
                                    }

                                    else {
                                        votes[0] += 1;
                                    }
                                }

                                else {
                                    if (x[8] <= -1.0053924918174744) {
                                        if (x[15] <= 27.191150665283203) {
                                            votes[1] += 1;
                                        }

                                        else {
                                            votes[0] += 1;
                                        }
                                    }

                                    else {
                                        votes[0] += 1;
                                    }
                                }
                            }
                        }

                        else {
                            if (x[3] <= 0.12575000151991844) {
                                votes[1] += 1;
                            }

                            else {
                                votes[0] += 1;
                            }
                        }

                        // tree #35
                        if (x[0] <= 0.12241499498486519) {
                            if (x[11] <= -0.972900003194809) {
                                votes[1] += 1;
                            }

                            else {
                                votes[0] += 1;
                            }
                        }

                        else {
                            votes[0] += 1;
                        }

                        // tree #36
                        if (x[2] <= 0.11789999902248383) {
                            if (x[6] <= -0.07665000110864639) {
                                if (x[12] <= 4.34418249130249) {
                                    votes[1] += 1;
                                }

                                else {
                                    votes[0] += 1;
                                }
                            }

                            else {
                                votes[1] += 1;
                            }
                        }

                        else {
                            votes[0] += 1;
                        }

                        // tree #37
                        if (x[6] <= -0.01635000016540289) {
                            if (x[3] <= 0.1279500015079975) {
                                votes[1] += 1;
                            }

                            else {
                                if (x[11] <= -0.9492499828338623) {
                                    votes[0] += 1;
                                }

                                else {
                                    votes[1] += 1;
                                }
                            }
                        }

                        else {
                            if (x[0] <= 0.11613499745726585) {
                                votes[1] += 1;
                            }

                            else {
                                votes[0] += 1;
                            }
                        }

                        // tree #38
                        if (x[12] <= 4.3792724609375) {
                            if (x[7] <= -0.004400000092573464) {
                                votes[1] += 1;
                            }

                            else {
                                if (x[13] <= 2.3047061562538147) {
                                    votes[0] += 1;
                                }

                                else {
                                    votes[1] += 1;
                                }
                            }
                        }

                        else {
                            if (x[3] <= 0.1181499995291233) {
                                votes[1] += 1;
                            }

                            else {
                                votes[0] += 1;
                            }
                        }

                        // tree #39
                        if (x[0] <= 0.12250999733805656) {
                            votes[1] += 1;
                        }

                        else {
                            votes[0] += 1;
                        }

                        // tree #40
                        if (x[7] <= -0.004850000026635826) {
                            votes[1] += 1;
                        }

                        else {
                            if (x[2] <= 0.07739999983459711) {
                                votes[1] += 1;
                            }

                            else {
                                votes[0] += 1;
                            }
                        }

                        // tree #41
                        if (x[4] <= -0.01198749989271164) {
                            votes[1] += 1;
                        }

                        else {
                            if (x[0] <= 0.11742249503731728) {
                                votes[1] += 1;
                            }

                            else {
                                votes[0] += 1;
                            }
                        }

                        // tree #42
                        if (x[4] <= -0.006039999891072512) {
                            if (x[8] <= -1.0031325221061707) {
                                votes[1] += 1;
                            }

                            else {
                                votes[0] += 1;
                            }
                        }

                        else {
                            votes[0] += 1;
                        }

                        // tree #43
                        if (x[10] <= -1.010949969291687) {
                            if (x[4] <= -0.01198749989271164) {
                                votes[1] += 1;
                            }

                            else {
                                if (x[11] <= -0.9492499828338623) {
                                    votes[0] += 1;
                                }

                                else {
                                    votes[1] += 1;
                                }
                            }
                        }

                        else {
                            votes[0] += 1;
                        }

                        // tree #44
                        if (x[2] <= 0.11789999902248383) {
                            if (x[25] <= 0.025663156993687153) {
                                votes[1] += 1;
                            }

                            else {
                                votes[0] += 1;
                            }
                        }

                        else {
                            votes[0] += 1;
                        }

                        // tree #45
                        if (x[10] <= -1.0124499797821045) {
                            if (x[7] <= -0.0039000000688247383) {
                                votes[1] += 1;
                            }

                            else {
                                if (x[11] <= -0.9519499838352203) {
                                    votes[0] += 1;
                                }

                                else {
                                    votes[1] += 1;
                                }
                            }
                        }

                        else {
                            if (x[3] <= 0.12525000050663948) {
                                votes[1] += 1;
                            }

                            else {
                                votes[0] += 1;
                            }
                        }

                        // tree #46
                        if (x[4] <= -0.01198749989271164) {
                            votes[1] += 1;
                        }

                        else {
                            if (x[21] <= 8.236480236053467) {
                                votes[0] += 1;
                            }

                            else {
                                if (x[0] <= 0.10637999698519707) {
                                    votes[1] += 1;
                                }

                                else {
                                    votes[0] += 1;
                                }
                            }
                        }

                        // tree #47
                        if (x[11] <= -0.9982500076293945) {
                            if (x[7] <= -0.0039000000688247383) {
                                votes[1] += 1;
                            }

                            else {
                                votes[0] += 1;
                            }
                        }

                        else {
                            if (x[4] <= -0.006039999891072512) {
                                votes[1] += 1;
                            }

                            else {
                                votes[0] += 1;
                            }
                        }

                        // tree #48
                        if (x[6] <= -0.015850000083446503) {
                            if (x[4] <= -0.012009999714791775) {
                                votes[1] += 1;
                            }

                            else {
                                if (x[18] <= -1.7699999809265137) {
                                    if (x[4] <= 0.004962500184774399) {
                                        votes[1] += 1;
                                    }

                                    else {
                                        votes[0] += 1;
                                    }
                                }

                                else {
                                    votes[0] += 1;
                                }
                            }
                        }

                        else {
                            if (x[4] <= -0.009455000050365925) {
                                votes[1] += 1;
                            }

                            else {
                                votes[0] += 1;
                            }
                        }

                        // tree #49
                        if (x[10] <= -1.0124499797821045) {
                            if (x[17] <= 0.18715187907218933) {
                                if (x[0] <= 0.1229575015604496) {
                                    votes[1] += 1;
                                }

                                else {
                                    votes[0] += 1;
                                }
                            }

                            else {
                                if (x[17] <= 1.0255491733551025) {
                                    votes[0] += 1;
                                }

                                else {
                                    if (x[24] <= 1.0187578797340393) {
                                        votes[1] += 1;
                                    }

                                    else {
                                        votes[0] += 1;
                                    }
                                }
                            }
                        }

                        else {
                            if (x[3] <= 0.12550000101327896) {
                                votes[1] += 1;
                            }

                            else {
                                votes[0] += 1;
                            }
                        }

                        // tree #50
                        if (x[2] <= 0.1164500005543232) {
                            if (x[24] <= 1.0187578797340393) {
                                votes[1] += 1;
                            }

                            else {
                                votes[0] += 1;
                            }
                        }

                        else {
                            votes[0] += 1;
                        }

                        // tree #51
                        if (x[0] <= 0.12222999706864357) {
                            votes[1] += 1;
                        }

                        else {
                            votes[0] += 1;
                        }

                        // tree #52
                        if (x[7] <= -0.0053499998757615685) {
                            votes[1] += 1;
                        }

                        else {
                            if (x[11] <= -0.9519499838352203) {
                                votes[0] += 1;
                            }

                            else {
                                votes[1] += 1;
                            }
                        }

                        // tree #53
                        if (x[0] <= 0.12241499498486519) {
                            votes[1] += 1;
                        }

                        else {
                            votes[0] += 1;
                        }

                        // tree #54
                        if (x[6] <= -0.015850000083446503) {
                            if (x[19] <= 1.5564000010490417) {
                                if (x[7] <= -0.003400000074179843) {
                                    votes[1] += 1;
                                }

                                else {
                                    votes[0] += 1;
                                }
                            }

                            else {
                                if (x[11] <= -0.9553499817848206) {
                                    votes[0] += 1;
                                }

                                else {
                                    votes[1] += 1;
                                }
                            }
                        }

                        else {
                            if (x[2] <= 0.11205000057816505) {
                                votes[1] += 1;
                            }

                            else {
                                votes[0] += 1;
                            }
                        }

                        // tree #55
                        if (x[3] <= 0.12649999931454659) {
                            votes[1] += 1;
                        }

                        else {
                            votes[0] += 1;
                        }

                        // tree #56
                        if (x[3] <= 0.1262499950826168) {
                            votes[1] += 1;
                        }

                        else {
                            if (x[21] <= 6.842277526855469) {
                                votes[0] += 1;
                            }

                            else {
                                if (x[0] <= 0.10637999698519707) {
                                    votes[1] += 1;
                                }

                                else {
                                    votes[0] += 1;
                                }
                            }
                        }

                        // tree #57
                        if (x[4] <= -0.01198749989271164) {
                            votes[1] += 1;
                        }

                        else {
                            if (x[15] <= 11.016849994659424) {
                                votes[0] += 1;
                            }

                            else {
                                if (x[21] <= 13.702428817749023) {
                                    votes[1] += 1;
                                }

                                else {
                                    votes[0] += 1;
                                }
                            }
                        }

                        // tree #58
                        if (x[15] <= 4.608150005340576) {
                            if (x[2] <= 0.11890000104904175) {
                                votes[1] += 1;
                            }

                            else {
                                votes[0] += 1;
                            }
                        }

                        else {
                            if (x[12] <= 4.385382413864136) {
                                if (x[3] <= 0.13014999777078629) {
                                    votes[1] += 1;
                                }

                                else {
                                    if (x[11] <= -0.9658499956130981) {
                                        votes[0] += 1;
                                    }

                                    else {
                                        votes[1] += 1;
                                    }
                                }
                            }

                            else {
                                if (x[4] <= -0.006039999891072512) {
                                    votes[1] += 1;
                                }

                                else {
                                    votes[0] += 1;
                                }
                            }
                        }

                        // tree #59
                        if (x[4] <= -0.010402499698102474) {
                            votes[1] += 1;
                        }

                        else {
                            if (x[23] <= 14.31275025010109) {
                                votes[0] += 1;
                            }

                            else {
                                if (x[19] <= 7.04954981803894) {
                                    votes[1] += 1;
                                }

                                else {
                                    votes[0] += 1;
                                }
                            }
                        }

                        // tree #60
                        if (x[20] <= -0.06407750025391579) {
                            if (x[5] <= 0.0023894956102594733) {
                                if (x[3] <= 0.12549999728798866) {
                                    votes[1] += 1;
                                }

                                else {
                                    votes[0] += 1;
                                }
                            }

                            else {
                                if (x[8] <= -1.004847526550293) {
                                    if (x[17] <= 1.7965369820594788) {
                                        votes[1] += 1;
                                    }

                                    else {
                                        votes[0] += 1;
                                    }
                                }

                                else {
                                    votes[0] += 1;
                                }
                            }
                        }

                        else {
                            if (x[4] <= -0.009329999797046185) {
                                votes[1] += 1;
                            }

                            else {
                                votes[0] += 1;
                            }
                        }

                        // tree #61
                        if (x[0] <= 0.12247249856591225) {
                            if (x[24] <= 1.034015953540802) {
                                votes[1] += 1;
                            }

                            else {
                                votes[0] += 1;
                            }
                        }

                        else {
                            votes[0] += 1;
                        }

                        // tree #62
                        if (x[8] <= -1.005025029182434) {
                            if (x[7] <= 0.025399999227374792) {
                                votes[1] += 1;
                            }

                            else {
                                if (x[10] <= -1.0598000288009644) {
                                    votes[1] += 1;
                                }

                                else {
                                    votes[0] += 1;
                                }
                            }
                        }

                        else {
                            if (x[2] <= -0.22484999895095825) {
                                votes[1] += 1;
                            }

                            else {
                                votes[0] += 1;
                            }
                        }

                        // tree #63
                        if (x[10] <= -1.0114499926567078) {
                            if (x[8] <= -1.0048649907112122) {
                                if (x[13] <= 6.845533490180969) {
                                    votes[1] += 1;
                                }

                                else {
                                    votes[0] += 1;
                                }
                            }

                            else {
                                votes[0] += 1;
                            }
                        }

                        else {
                            if (x[8] <= -1.0056650042533875) {
                                votes[1] += 1;
                            }

                            else {
                                votes[0] += 1;
                            }
                        }

                        // tree #64
                        if (x[6] <= -0.015850000083446503) {
                            if (x[3] <= 0.12844999507069588) {
                                votes[1] += 1;
                            }

                            else {
                                if (x[2] <= 0.04125000070780516) {
                                    if (x[8] <= -1.0220900177955627) {
                                        votes[0] += 1;
                                    }

                                    else {
                                        votes[1] += 1;
                                    }
                                }

                                else {
                                    votes[0] += 1;
                                }
                            }
                        }

                        else {
                            if (x[7] <= -0.005099999951198697) {
                                votes[1] += 1;
                            }

                            else {
                                votes[0] += 1;
                            }
                        }

                        // tree #65
                        if (x[6] <= -0.015350000467151403) {
                            if (x[3] <= 0.1279500015079975) {
                                votes[1] += 1;
                            }

                            else {
                                if (x[11] <= -0.9492499828338623) {
                                    votes[0] += 1;
                                }

                                else {
                                    votes[1] += 1;
                                }
                            }
                        }

                        else {
                            votes[0] += 1;
                        }

                        // tree #66
                        if (x[3] <= 0.1262499950826168) {
                            votes[1] += 1;
                        }

                        else {
                            if (x[2] <= 0.04125000070780516) {
                                if (x[4] <= 0.004962500184774399) {
                                    votes[1] += 1;
                                }

                                else {
                                    votes[0] += 1;
                                }
                            }

                            else {
                                votes[0] += 1;
                            }
                        }

                        // tree #67
                        if (x[20] <= -0.06407750025391579) {
                            if (x[24] <= 1.012846291065216) {
                                if (x[0] <= 0.1220649965107441) {
                                    votes[1] += 1;
                                }

                                else {
                                    votes[0] += 1;
                                }
                            }

                            else {
                                if (x[3] <= 0.12965000048279762) {
                                    votes[1] += 1;
                                }

                                else {
                                    votes[0] += 1;
                                }
                            }
                        }

                        else {
                            if (x[2] <= 0.11789999902248383) {
                                if (x[21] <= 14.067803382873535) {
                                    votes[1] += 1;
                                }

                                else {
                                    votes[0] += 1;
                                }
                            }

                            else {
                                votes[0] += 1;
                            }
                        }

                        // tree #68
                        if (x[3] <= 0.1262499950826168) {
                            votes[1] += 1;
                        }

                        else {
                            if (x[14] <= 1.0070999562740326) {
                                if (x[7] <= 0.24000000953674316) {
                                    votes[1] += 1;
                                }

                                else {
                                    votes[0] += 1;
                                }
                            }

                            else {
                                votes[0] += 1;
                            }
                        }

                        // tree #69
                        if (x[8] <= -1.0048850178718567) {
                            votes[1] += 1;
                        }

                        else {
                            if (x[7] <= 0.028850000351667404) {
                                votes[0] += 1;
                            }

                            else {
                                votes[1] += 1;
                            }
                        }

                        // tree #70
                        if (x[11] <= -0.9982500076293945) {
                            if (x[7] <= -0.0034000000450760126) {
                                votes[1] += 1;
                            }

                            else {
                                votes[0] += 1;
                            }
                        }

                        else {
                            if (x[12] <= 4.376219987869263) {
                                if (x[8] <= -1.0047624707221985) {
                                    votes[1] += 1;
                                }

                                else {
                                    votes[0] += 1;
                                }
                            }

                            else {
                                if (x[20] <= -0.3936774879693985) {
                                    votes[1] += 1;
                                }

                                else {
                                    votes[0] += 1;
                                }
                            }
                        }

                        // tree #71
                        if (x[8] <= -1.005025029182434) {
                            if (x[19] <= 7.04954981803894) {
                                votes[1] += 1;
                            }

                            else {
                                votes[0] += 1;
                            }
                        }

                        else {
                            if (x[5] <= 0.026916232891380787) {
                                votes[0] += 1;
                            }

                            else {
                                votes[1] += 1;
                            }
                        }

                        // tree #72
                        if (x[2] <= 0.1164500005543232) {
                            if (x[24] <= 1.034015953540802) {
                                votes[1] += 1;
                            }

                            else {
                                votes[0] += 1;
                            }
                        }

                        else {
                            votes[0] += 1;
                        }

                        // tree #73
                        if (x[7] <= -0.0053499998757615685) {
                            votes[1] += 1;
                        }

                        else {
                            if (x[18] <= -1.0375999752432108) {
                                votes[1] += 1;
                            }

                            else {
                                votes[0] += 1;
                            }
                        }

                        // tree #74
                        if (x[0] <= 0.12250999733805656) {
                            if (x[18] <= -9.765650033950806) {
                                votes[0] += 1;
                            }

                            else {
                                votes[1] += 1;
                            }
                        }

                        else {
                            votes[0] += 1;
                        }

                        // tree #75
                        if (x[4] <= -0.012042499613016844) {
                            votes[1] += 1;
                        }

                        else {
                            if (x[12] <= 4.806522369384766) {
                                votes[0] += 1;
                            }

                            else {
                                votes[1] += 1;
                            }
                        }

                        // tree #76
                        if (x[2] <= 0.1164500005543232) {
                            if (x[16] <= 0.3646800220012665) {
                                votes[0] += 1;
                            }

                            else {
                                votes[1] += 1;
                            }
                        }

                        else {
                            votes[0] += 1;
                        }

                        // tree #77
                        if (x[4] <= -0.01198749989271164) {
                            votes[1] += 1;
                        }

                        else {
                            if (x[11] <= -0.9492499828338623) {
                                votes[0] += 1;
                            }

                            else {
                                votes[1] += 1;
                            }
                        }

                        // tree #78
                        if (x[3] <= 0.12599999830126762) {
                            votes[1] += 1;
                        }

                        else {
                            if (x[13] <= 2.3047061562538147) {
                                votes[0] += 1;
                            }

                            else {
                                votes[1] += 1;
                            }
                        }

                        // tree #79
                        if (x[4] <= -0.01198749989271164) {
                            votes[1] += 1;
                        }

                        else {
                            votes[0] += 1;
                        }

                        // tree #80
                        if (x[3] <= 0.12649999931454659) {
                            votes[1] += 1;
                        }

                        else {
                            if (x[23] <= 12.969949558377266) {
                                votes[0] += 1;
                            }

                            else {
                                votes[1] += 1;
                            }
                        }

                        // tree #81
                        if (x[4] <= -0.009455000050365925) {
                            votes[1] += 1;
                        }

                        else {
                            votes[0] += 1;
                        }

                        // tree #82
                        if (x[4] <= -0.01034749997779727) {
                            votes[1] += 1;
                        }

                        else {
                            if (x[20] <= -0.3707899823784828) {
                                votes[1] += 1;
                            }

                            else {
                                votes[0] += 1;
                            }
                        }

                        // tree #83
                        if (x[6] <= -0.01635000016540289) {
                            if (x[1] <= 0.002713734866119921) {
                                if (x[12] <= 4.414367437362671) {
                                    votes[1] += 1;
                                }

                                else {
                                    votes[0] += 1;
                                }
                            }

                            else {
                                if (x[3] <= 0.12254999950528145) {
                                    votes[1] += 1;
                                }

                                else {
                                    if (x[0] <= 0.10460750013589859) {
                                        votes[1] += 1;
                                    }

                                    else {
                                        votes[0] += 1;
                                    }
                                }
                            }
                        }

                        else {
                            if (x[7] <= -0.0051499999826774) {
                                votes[1] += 1;
                            }

                            else {
                                votes[0] += 1;
                            }
                        }

                        // tree #84
                        if (x[0] <= 0.12241499498486519) {
                            if (x[8] <= -1.0238550305366516) {
                                votes[0] += 1;
                            }

                            else {
                                votes[1] += 1;
                            }
                        }

                        else {
                            votes[0] += 1;
                        }

                        // tree #85
                        if (x[7] <= -0.004600000102072954) {
                            votes[1] += 1;
                        }

                        else {
                            if (x[10] <= -1.0515000224113464) {
                                if (x[8] <= -1.0220900177955627) {
                                    votes[0] += 1;
                                }

                                else {
                                    votes[1] += 1;
                                }
                            }

                            else {
                                votes[0] += 1;
                            }
                        }

                        // tree #86
                        if (x[8] <= -1.0047950148582458) {
                            if (x[23] <= 38.848899841308594) {
                                votes[1] += 1;
                            }

                            else {
                                votes[0] += 1;
                            }
                        }

                        else {
                            if (x[21] <= 6.203254416584969) {
                                votes[0] += 1;
                            }

                            else {
                                votes[1] += 1;
                            }
                        }

                        // tree #87
                        if (x[11] <= -0.9982500076293945) {
                            if (x[6] <= -0.014150000177323818) {
                                votes[1] += 1;
                            }

                            else {
                                votes[0] += 1;
                            }
                        }

                        else {
                            if (x[4] <= -0.01240250002592802) {
                                votes[1] += 1;
                            }

                            else {
                                votes[0] += 1;
                            }
                        }

                        // tree #88
                        if (x[7] <= -0.004600000102072954) {
                            votes[1] += 1;
                        }

                        else {
                            if (x[4] <= -0.006019999971613288) {
                                votes[1] += 1;
                            }

                            else {
                                votes[0] += 1;
                            }
                        }

                        // tree #89
                        if (x[0] <= 0.12227999791502953) {
                            if (x[15] <= 31.005850315093994) {
                                votes[1] += 1;
                            }

                            else {
                                votes[0] += 1;
                            }
                        }

                        else {
                            votes[0] += 1;
                        }

                        // tree #90
                        if (x[24] <= 1.0118348002433777) {
                            if (x[0] <= 0.1220649965107441) {
                                votes[1] += 1;
                            }

                            else {
                                votes[0] += 1;
                            }
                        }

                        else {
                            if (x[6] <= -0.014400000218302011) {
                                if (x[0] <= 0.12595750018954277) {
                                    if (x[15] <= 31.646750450134277) {
                                        votes[1] += 1;
                                    }

                                    else {
                                        votes[0] += 1;
                                    }
                                }

                                else {
                                    votes[0] += 1;
                                }
                            }

                            else {
                                votes[0] += 1;
                            }
                        }

                        // tree #91
                        if (x[4] <= -0.01198749989271164) {
                            votes[1] += 1;
                        }

                        else {
                            if (x[9] <= 0.023516396060585976) {
                                votes[0] += 1;
                            }

                            else {
                                if (x[7] <= 0.24000000953674316) {
                                    votes[1] += 1;
                                }

                                else {
                                    votes[0] += 1;
                                }
                            }
                        }

                        // tree #92
                        if (x[10] <= -1.0114499926567078) {
                            if (x[2] <= 0.11820000037550926) {
                                votes[1] += 1;
                            }

                            else {
                                votes[0] += 1;
                            }
                        }

                        else {
                            if (x[20] <= 0.010684999637305737) {
                                votes[0] += 1;
                            }

                            else {
                                votes[1] += 1;
                            }
                        }

                        // tree #93
                        if (x[6] <= -0.015850000083446503) {
                            if (x[5] <= 0.00353985617402941) {
                                votes[1] += 1;
                            }

                            else {
                                if (x[15] <= 11.016849994659424) {
                                    votes[0] += 1;
                                }

                                else {
                                    if (x[2] <= -0.052749997936189175) {
                                        votes[0] += 1;
                                    }

                                    else {
                                        votes[1] += 1;
                                    }
                                }
                            }
                        }

                        else {
                            if (x[5] <= 0.001603737415280193) {
                                if (x[8] <= -1.0048800110816956) {
                                    votes[1] += 1;
                                }

                                else {
                                    votes[0] += 1;
                                }
                            }

                            else {
                                votes[0] += 1;
                            }
                        }

                        // tree #94
                        if (x[4] <= -0.01198749989271164) {
                            votes[1] += 1;
                        }

                        else {
                            if (x[14] <= -0.4882500022649765) {
                                votes[1] += 1;
                            }

                            else {
                                votes[0] += 1;
                            }
                        }

                        // tree #95
                        if (x[7] <= -0.004850000026635826) {
                            votes[1] += 1;
                        }

                        else {
                            if (x[4] <= -0.014285000041127205) {
                                votes[1] += 1;
                            }

                            else {
                                votes[0] += 1;
                            }
                        }

                        // tree #96
                        if (x[7] <= -0.004600000102072954) {
                            votes[1] += 1;
                        }

                        else {
                            if (x[13] <= 1.9819134771823883) {
                                votes[0] += 1;
                            }

                            else {
                                if (x[20] <= 3.437804877758026) {
                                    votes[1] += 1;
                                }

                                else {
                                    votes[0] += 1;
                                }
                            }
                        }

                        // tree #97
                        if (x[24] <= 1.0120978355407715) {
                            if (x[7] <= -0.006350000039674342) {
                                votes[1] += 1;
                            }

                            else {
                                votes[0] += 1;
                            }
                        }

                        else {
                            if (x[4] <= -0.012009999714791775) {
                                votes[1] += 1;
                            }

                            else {
                                if (x[14] <= 0.33570000529289246) {
                                    if (x[15] <= 31.646750450134277) {
                                        votes[1] += 1;
                                    }

                                    else {
                                        votes[0] += 1;
                                    }
                                }

                                else {
                                    votes[0] += 1;
                                }
                            }
                        }

                        // tree #98
                        if (x[8] <= -1.0047749876976013) {
                            if (x[6] <= -0.15405000001192093) {
                                votes[0] += 1;
                            }

                            else {
                                votes[1] += 1;
                            }
                        }

                        else {
                            if (x[21] <= 6.203254416584969) {
                                votes[0] += 1;
                            }

                            else {
                                votes[1] += 1;
                            }
                        }

                        // tree #99
                        if (x[0] <= 0.12250999733805656) {
                            if (x[9] <= 0.043524835258722305) {
                                votes[1] += 1;
                            }

                            else {
                                votes[0] += 1;
                            }
                        }

                        else {
                            votes[0] += 1;
                        }

                        // tree #100
                        if (x[0] <= 0.12241499498486519) {
                            if (x[8] <= -1.0233874917030334) {
                                votes[0] += 1;
                            }

                            else {
                                votes[1] += 1;
                            }
                        }

                        else {
                            votes[0] += 1;
                        }

                        // return argmax of votes
                        uint8_t classIdx = 0;
                        float maxVotes = votes[0];

                        for (uint8_t i = 1; i < 2; i++) {
                            if (votes[i] > maxVotes) {
                                classIdx = i;
                                maxVotes = votes[i];
                            }
                        }

                        return classIdx;
                    }

                    /**
                    * Predict readable class name
                    */
                    const char* predictLabel(float *x) {
                        return idxToLabel(predict(x));
                    }

                    /**
                    * Convert class idx to readable name
                    */
                    const char* idxToLabel(uint8_t classIdx) {
                        switch (classIdx) {
                            case 0:
                            return "lying";
                            case 1:
                            return "standing";
                            default:
                            return "Houston we have a problem";
                        }
                    }

                protected:
                };
            }
        }
    }