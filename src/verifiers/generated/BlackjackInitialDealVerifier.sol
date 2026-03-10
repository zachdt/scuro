// SPDX-License-Identifier: GPL-3.0
/*
    Copyright 2021 0KIMS association.

    This file is generated with [snarkJS](https://github.com/iden3/snarkjs).

    snarkJS is a free software: you can redistribute it and/or modify it
    under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    snarkJS is distributed in the hope that it will be useful, but WITHOUT
    ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
    or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public
    License for more details.

    You should have received a copy of the GNU General Public License
    along with snarkJS. If not, see <https://www.gnu.org/licenses/>.
*/

pragma solidity >=0.7.0 <0.9.0;

contract BlackjackInitialDealVerifier {
    // Scalar field size
    uint256 constant r    = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
    // Base field size
    uint256 constant q   = 21888242871839275222246405745257275088696311157297823662689037894645226208583;

    // Verification Key data
    uint256 constant alphax  = 5357486762750547763894099768622049277094915015919213565139357978777662782304;
    uint256 constant alphay  = 10607267220437769230113375640453244228920782776283083462499005137686963394046;
    uint256 constant betax1  = 16389192845903415571457138014577476370724271859956167562610863588841263859796;
    uint256 constant betax2  = 17432211900774682868679786146042359414485306330191417978252039248886651004425;
    uint256 constant betay1  = 1616887969358894033906341518649972022736041914580546238549954870880344722022;
    uint256 constant betay2  = 7258877284214958503381038950105338251026862874227765945909767641467129035964;
    uint256 constant gammax1 = 11559732032986387107991004021392285783925812861821192530917403151452391805634;
    uint256 constant gammax2 = 10857046999023057135944570762232829481370756359578518086990519993285655852781;
    uint256 constant gammay1 = 4082367875863433681332203403145435568316851327593401208105741076214120093531;
    uint256 constant gammay2 = 8495653923123431417604973247489272438418190587263600148770280649306958101930;
    uint256 constant deltax1 = 21061324522496955605507707170073428094776639011327217487890301310780935350477;
    uint256 constant deltax2 = 287862551016577461465629930999935789882124246182189589744544835232606042748;
    uint256 constant deltay1 = 5746751790056822771916756156947576990516030257492776421894204167350364406093;
    uint256 constant deltay2 = 11554599095053983751358032585850606859922459002333962746411258360662540629770;

    
    uint256 constant IC0x = 13202884775976074823304301264103303551344504597000559645435925535988223536315;
    uint256 constant IC0y = 14933578064352662522706603740112132074263625259676475052054895816385484879121;
    
    uint256 constant IC1x = 21483199657908993719165040118062390656648450711315374360783487595605189102645;
    uint256 constant IC1y = 3974092226537322765278824006813721878596819067762943102797349576364565919477;
    
    uint256 constant IC2x = 18061288339335980545725140657933316580376465381850565080107253280414815790901;
    uint256 constant IC2y = 16940221016710161104146313969277380254304320132580258390335762068496606689086;
    
    uint256 constant IC3x = 8056283591587388968886093967204712929885800466170315604285734496606994610732;
    uint256 constant IC3y = 17170763898044037925163078694583175257879587139838506228358218576908040787317;
    
    uint256 constant IC4x = 703669882189899237719216632711678519405900208619080863554916787556511074445;
    uint256 constant IC4y = 4240240097344995549993375442424573828653049571166123877463478393799137586171;
    
    uint256 constant IC5x = 13455322051050692023797873307012062698688674951603410677056056142241162350603;
    uint256 constant IC5y = 5749667313371566585153085823408070437163350302041719822633693507664533474071;
    
    uint256 constant IC6x = 5461629610143673182933291462556774556409814699304232093111831147626061618735;
    uint256 constant IC6y = 21559235282804279824995993393348017497719462415028699612396937615423659657697;
    
    uint256 constant IC7x = 9107331531536283075634120006467549301594120465717554597475947862907196650319;
    uint256 constant IC7y = 12789247378044990938427317854680634216713263520319030498647314271838153087005;
    
    uint256 constant IC8x = 12700443298881734301646729722525220044519624913945718990482656739447328081307;
    uint256 constant IC8y = 21413978441170223816559340857589056265199005962785494735459945425041936936164;
    
    uint256 constant IC9x = 2417675094108860328240420953682833495020737132807646562915958409983867780059;
    uint256 constant IC9y = 3695935285352520937989416613620814092092510597215987322514282814053220791377;
    
    uint256 constant IC10x = 15964988403220052657765386711004420775836362987669482263933587723930204184998;
    uint256 constant IC10y = 9019153755529660045950655728441631265562220214699773726189255836959309335853;
    
    uint256 constant IC11x = 6509383561851035545469833807617508938708221077590518772670452134860866372238;
    uint256 constant IC11y = 6350666133405167803469763463498502993270114657230072968225632698997796801671;
    
    uint256 constant IC12x = 18745958440780877032078699625136433687576692455533708795042343348080778558430;
    uint256 constant IC12y = 8624763784517019869411007485151948065331055368954690283252266478870530509232;
    
    uint256 constant IC13x = 9886192299448831697817450509058875034986832589939438582860101234675833105350;
    uint256 constant IC13y = 21180916181364062420953524798892773835435117288542005793301942901860943002196;
    
    uint256 constant IC14x = 17132301892330216030454503630977025524766764666637933581410458280339003472238;
    uint256 constant IC14y = 12633541071478696079683668828576660403891976038196627017400399311639611754962;
    
    uint256 constant IC15x = 12639374713422855990956894652986583410798521150495028169901420096822947607078;
    uint256 constant IC15y = 6853270118288082561337990581811580675330663701111184828029698476764075123604;
    
    uint256 constant IC16x = 20737815851959541208923487199541779957634123879254933478182990521255505790926;
    uint256 constant IC16y = 19202353964453595875078074772515456113310537574695271748102752350244156600000;
    
    uint256 constant IC17x = 13387695616007447568839807511453223203981285511274251879470655638939770300466;
    uint256 constant IC17y = 13377370659457391227914263093052291454873917594218577295209783196519681978385;
    
    uint256 constant IC18x = 4676229292679160676464960925467492437892657585409833242343971001662706998085;
    uint256 constant IC18y = 5550671620667567469594316824319065515812683228013928288565031696629769007500;
    
    uint256 constant IC19x = 18804781762820995863923829808055864195948684643535386734127155466204196455173;
    uint256 constant IC19y = 18077504505419285605929622594344463089875134031866948109212798553410934129603;
    
    uint256 constant IC20x = 7058242492211451413330482026652346539431650765147090833258247607339468422810;
    uint256 constant IC20y = 9297506505756818702262662210647159183570174197486121182356282975845718859011;
    
    uint256 constant IC21x = 3849234699952740851258179497305419549312689110604579312678132516741992755318;
    uint256 constant IC21y = 17607920112873563602456017622739073172147184678466946286366517929170792155104;
    
    uint256 constant IC22x = 16958575736989705126211401964605905615429585917050249780079727093405897003449;
    uint256 constant IC22y = 20883655689330792728882935366739289966396030627452664058557367759414051163275;
    
    uint256 constant IC23x = 11990856946276937542759793476295226089464354493450877322659690066896005884665;
    uint256 constant IC23y = 6117717318118066417710693026783081790851229780086009870766958512769344696450;
    
    uint256 constant IC24x = 1060107127410267236903374337871575904421664973260193417699093514176708030579;
    uint256 constant IC24y = 1715556048919256467106948032687340472252654259264323329689287274611375650388;
    
    uint256 constant IC25x = 18421301163345296513045863217905683423126067079758996943734045094180981685856;
    uint256 constant IC25y = 3705532208713101047318640611406726300172850530005046824135212256186641338136;
    
    uint256 constant IC26x = 8664095379698403870441390093446698229007791713072862099708257052365111652951;
    uint256 constant IC26y = 5089531342434850046752337741527946793997589160844096240782833432731129002124;
    
 
    // Memory data
    uint16 constant pVk = 0;
    uint16 constant pPairing = 128;

    uint16 constant pLastMem = 896;

    function verifyProof(uint[2] calldata _pA, uint[2][2] calldata _pB, uint[2] calldata _pC, uint[26] calldata _pubSignals) public view returns (bool) {
        assembly {
            function checkField(v) {
                if iszero(lt(v, r)) {
                    mstore(0, 0)
                    return(0, 0x20)
                }
            }
            
            // G1 function to multiply a G1 value(x,y) to value in an address
            function g1_mulAccC(pR, x, y, s) {
                let success
                let mIn := mload(0x40)
                mstore(mIn, x)
                mstore(add(mIn, 32), y)
                mstore(add(mIn, 64), s)

                success := staticcall(sub(gas(), 2000), 7, mIn, 96, mIn, 64)

                if iszero(success) {
                    mstore(0, 0)
                    return(0, 0x20)
                }

                mstore(add(mIn, 64), mload(pR))
                mstore(add(mIn, 96), mload(add(pR, 32)))

                success := staticcall(sub(gas(), 2000), 6, mIn, 128, pR, 64)

                if iszero(success) {
                    mstore(0, 0)
                    return(0, 0x20)
                }
            }

            function checkPairing(pA, pB, pC, pubSignals, pMem) -> isOk {
                let _pPairing := add(pMem, pPairing)
                let _pVk := add(pMem, pVk)

                mstore(_pVk, IC0x)
                mstore(add(_pVk, 32), IC0y)

                // Compute the linear combination vk_x
                
                g1_mulAccC(_pVk, IC1x, IC1y, calldataload(add(pubSignals, 0)))
                
                g1_mulAccC(_pVk, IC2x, IC2y, calldataload(add(pubSignals, 32)))
                
                g1_mulAccC(_pVk, IC3x, IC3y, calldataload(add(pubSignals, 64)))
                
                g1_mulAccC(_pVk, IC4x, IC4y, calldataload(add(pubSignals, 96)))
                
                g1_mulAccC(_pVk, IC5x, IC5y, calldataload(add(pubSignals, 128)))
                
                g1_mulAccC(_pVk, IC6x, IC6y, calldataload(add(pubSignals, 160)))
                
                g1_mulAccC(_pVk, IC7x, IC7y, calldataload(add(pubSignals, 192)))
                
                g1_mulAccC(_pVk, IC8x, IC8y, calldataload(add(pubSignals, 224)))
                
                g1_mulAccC(_pVk, IC9x, IC9y, calldataload(add(pubSignals, 256)))
                
                g1_mulAccC(_pVk, IC10x, IC10y, calldataload(add(pubSignals, 288)))
                
                g1_mulAccC(_pVk, IC11x, IC11y, calldataload(add(pubSignals, 320)))
                
                g1_mulAccC(_pVk, IC12x, IC12y, calldataload(add(pubSignals, 352)))
                
                g1_mulAccC(_pVk, IC13x, IC13y, calldataload(add(pubSignals, 384)))
                
                g1_mulAccC(_pVk, IC14x, IC14y, calldataload(add(pubSignals, 416)))
                
                g1_mulAccC(_pVk, IC15x, IC15y, calldataload(add(pubSignals, 448)))
                
                g1_mulAccC(_pVk, IC16x, IC16y, calldataload(add(pubSignals, 480)))
                
                g1_mulAccC(_pVk, IC17x, IC17y, calldataload(add(pubSignals, 512)))
                
                g1_mulAccC(_pVk, IC18x, IC18y, calldataload(add(pubSignals, 544)))
                
                g1_mulAccC(_pVk, IC19x, IC19y, calldataload(add(pubSignals, 576)))
                
                g1_mulAccC(_pVk, IC20x, IC20y, calldataload(add(pubSignals, 608)))
                
                g1_mulAccC(_pVk, IC21x, IC21y, calldataload(add(pubSignals, 640)))
                
                g1_mulAccC(_pVk, IC22x, IC22y, calldataload(add(pubSignals, 672)))
                
                g1_mulAccC(_pVk, IC23x, IC23y, calldataload(add(pubSignals, 704)))
                
                g1_mulAccC(_pVk, IC24x, IC24y, calldataload(add(pubSignals, 736)))
                
                g1_mulAccC(_pVk, IC25x, IC25y, calldataload(add(pubSignals, 768)))
                
                g1_mulAccC(_pVk, IC26x, IC26y, calldataload(add(pubSignals, 800)))
                

                // -A
                mstore(_pPairing, calldataload(pA))
                mstore(add(_pPairing, 32), mod(sub(q, calldataload(add(pA, 32))), q))

                // B
                mstore(add(_pPairing, 64), calldataload(pB))
                mstore(add(_pPairing, 96), calldataload(add(pB, 32)))
                mstore(add(_pPairing, 128), calldataload(add(pB, 64)))
                mstore(add(_pPairing, 160), calldataload(add(pB, 96)))

                // alpha1
                mstore(add(_pPairing, 192), alphax)
                mstore(add(_pPairing, 224), alphay)

                // beta2
                mstore(add(_pPairing, 256), betax1)
                mstore(add(_pPairing, 288), betax2)
                mstore(add(_pPairing, 320), betay1)
                mstore(add(_pPairing, 352), betay2)

                // vk_x
                mstore(add(_pPairing, 384), mload(add(pMem, pVk)))
                mstore(add(_pPairing, 416), mload(add(pMem, add(pVk, 32))))


                // gamma2
                mstore(add(_pPairing, 448), gammax1)
                mstore(add(_pPairing, 480), gammax2)
                mstore(add(_pPairing, 512), gammay1)
                mstore(add(_pPairing, 544), gammay2)

                // C
                mstore(add(_pPairing, 576), calldataload(pC))
                mstore(add(_pPairing, 608), calldataload(add(pC, 32)))

                // delta2
                mstore(add(_pPairing, 640), deltax1)
                mstore(add(_pPairing, 672), deltax2)
                mstore(add(_pPairing, 704), deltay1)
                mstore(add(_pPairing, 736), deltay2)


                let success := staticcall(sub(gas(), 2000), 8, _pPairing, 768, _pPairing, 0x20)

                isOk := and(success, mload(_pPairing))
            }

            let pMem := mload(0x40)
            mstore(0x40, add(pMem, pLastMem))

            // Validate that all evaluations ∈ F
            
            checkField(calldataload(add(_pubSignals, 0)))
            
            checkField(calldataload(add(_pubSignals, 32)))
            
            checkField(calldataload(add(_pubSignals, 64)))
            
            checkField(calldataload(add(_pubSignals, 96)))
            
            checkField(calldataload(add(_pubSignals, 128)))
            
            checkField(calldataload(add(_pubSignals, 160)))
            
            checkField(calldataload(add(_pubSignals, 192)))
            
            checkField(calldataload(add(_pubSignals, 224)))
            
            checkField(calldataload(add(_pubSignals, 256)))
            
            checkField(calldataload(add(_pubSignals, 288)))
            
            checkField(calldataload(add(_pubSignals, 320)))
            
            checkField(calldataload(add(_pubSignals, 352)))
            
            checkField(calldataload(add(_pubSignals, 384)))
            
            checkField(calldataload(add(_pubSignals, 416)))
            
            checkField(calldataload(add(_pubSignals, 448)))
            
            checkField(calldataload(add(_pubSignals, 480)))
            
            checkField(calldataload(add(_pubSignals, 512)))
            
            checkField(calldataload(add(_pubSignals, 544)))
            
            checkField(calldataload(add(_pubSignals, 576)))
            
            checkField(calldataload(add(_pubSignals, 608)))
            
            checkField(calldataload(add(_pubSignals, 640)))
            
            checkField(calldataload(add(_pubSignals, 672)))
            
            checkField(calldataload(add(_pubSignals, 704)))
            
            checkField(calldataload(add(_pubSignals, 736)))
            
            checkField(calldataload(add(_pubSignals, 768)))
            
            checkField(calldataload(add(_pubSignals, 800)))
            

            // Validate all evaluations
            let isValid := checkPairing(_pA, _pB, _pC, _pubSignals, pMem)

            mstore(0, isValid)
             return(0, 0x20)
         }
     }
 }
