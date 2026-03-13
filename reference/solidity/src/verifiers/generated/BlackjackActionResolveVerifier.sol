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

contract BlackjackActionResolveVerifier {
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
    uint256 constant deltax1 = 5272586534072725626800064685441390135610455961284236504891784618221634517028;
    uint256 constant deltax2 = 14289494486540146312890572628694404970085342906716501173568974843650888122950;
    uint256 constant deltay1 = 19490974236000386591514788926337214803781256716693048644042192514728043470578;
    uint256 constant deltay2 = 3372210877969586964590253253258646470046702233553343804051959305890679330058;

    
    uint256 constant IC0x = 4841518797624549494589208149368259310268297174674049025360404619554578818566;
    uint256 constant IC0y = 11223460093725928062715344122574854452726923201138173726563495731018381670617;
    
    uint256 constant IC1x = 14641308088371122063905515516080689314192167162316269735987437123937954516198;
    uint256 constant IC1y = 1148565554442436854735521629793253265914975215154741864453640438018674352840;
    
    uint256 constant IC2x = 15101339951638397308065199545613122721230731980393026311182316465667155620857;
    uint256 constant IC2y = 17111203400587784673264761515689286509320693905178206315435290739657336401485;
    
    uint256 constant IC3x = 17401904825712093293077681007108819809589948611348696066585364081806694806306;
    uint256 constant IC3y = 20777333489518607484877338053673131365780908300532642659680300411159818431993;
    
    uint256 constant IC4x = 21766531043530313148704384696908179275631725568512069716340916957276603192496;
    uint256 constant IC4y = 21860028095979299159526249281755221420375715294044424088292637775468438034444;
    
    uint256 constant IC5x = 15840255976863355359073176558943625085515125161096929766379233784491859643765;
    uint256 constant IC5y = 4906895012274186046208492594089745406908915843992395243406977244929989466403;
    
    uint256 constant IC6x = 21540224203266295743387739642742020817297084431052739167919112040043081271646;
    uint256 constant IC6y = 2473098387307379095422594059649568933259130283396074072458461641891391546483;
    
    uint256 constant IC7x = 17970848305845889200365380305895080976836297181891504432413715239259562894965;
    uint256 constant IC7y = 13997319352488819252066217032551432189857186758655966728495988085378999910160;
    
    uint256 constant IC8x = 10775087768371159057918887606958489041135327045250543387521405470794887823528;
    uint256 constant IC8y = 19878015388351955525322635600581568846400399486613917239610201358020209998839;
    
    uint256 constant IC9x = 17852529767714198870921239158041006093293652251801097403491830936267779409021;
    uint256 constant IC9y = 3762751750709195510236224854171540425380518148541202257562974722155699472235;
    
    uint256 constant IC10x = 12243847990281991063791314134865879691840637330200089379121692751481731603742;
    uint256 constant IC10y = 3292012883401836188947107042610655639645774875570379803318329038770298892262;
    
    uint256 constant IC11x = 14133043469191588390093577058162345663674418533377262223928804789138988602805;
    uint256 constant IC11y = 4679132326230430144949275404153625914831955562057991565584655100884340651654;
    
    uint256 constant IC12x = 15822584486067778557734183002298326729091977497221234366847038756328291328376;
    uint256 constant IC12y = 2114977062757982136234137192214942395653791653742261185055117603721117622545;
    
    uint256 constant IC13x = 7063633896954791176632830917420514094563912661237697917702445458511766511741;
    uint256 constant IC13y = 20739337505648028500459796863607844954588034440690200933641730565927661546020;
    
    uint256 constant IC14x = 13055968502299496755770919398099370814930024252710843863818601622723596224201;
    uint256 constant IC14y = 1035721939133237562270698114760957496749041031904223565474165815132205051512;
    
    uint256 constant IC15x = 9046388693107202804016393047426289606002128551074849016261690294616765699084;
    uint256 constant IC15y = 19349622825918108451296640109156372436994559977560751829505785363939785697176;
    
    uint256 constant IC16x = 15921678209600587668749470943285395741380553994026316904382740546215130333167;
    uint256 constant IC16y = 5842596663572363634095819736067872327556771902787151062073312868617059698739;
    
    uint256 constant IC17x = 4966630919301162264813188087163055463539814487989841233307848174328755796256;
    uint256 constant IC17y = 3697359237179585352308994444627725024219053087385270921164538348233626719258;
    
    uint256 constant IC18x = 1890236336599968942630400929503464850113370242405161341847560668900775268160;
    uint256 constant IC18y = 5620983295995682747435203096997783314310733332276188169511127078700611365671;
    
    uint256 constant IC19x = 8846480097690108793492377302744748799296499894180756224710504489052199766948;
    uint256 constant IC19y = 182448396705849365622381452455830076732751125631006488155589019442286711197;
    
    uint256 constant IC20x = 3333933277484710402607424273939366070910879417109761213552154192480795039774;
    uint256 constant IC20y = 18686965278811322180961276958184119835528632408925729923465609863860867847463;
    
    uint256 constant IC21x = 2174463584884361818629569805414494983890099999649257196582871163599807850448;
    uint256 constant IC21y = 8490799209523962599759799903627719264951712239659525015253564959912029240461;
    
    uint256 constant IC22x = 11956090578262212544326403547380414170237526103065814461309362654550092822284;
    uint256 constant IC22y = 9107444222293383784020203266243742643921524436183594081250107891379023904693;
    
    uint256 constant IC23x = 5874705703084307321468703790881575402605821589063214880022140674875541950231;
    uint256 constant IC23y = 3031076791477271653013066984994813638815546927211059716680599001719808321772;
    
    uint256 constant IC24x = 15834233560199171329055875854519212261322528056945825390770617650950367145405;
    uint256 constant IC24y = 15718378879746958426362792829685185431336169324087202630586993166095272824630;
    
    uint256 constant IC25x = 13885405628646332773739555529201073934222300557027974142184374037351906091365;
    uint256 constant IC25y = 8731122572461754221279700502479580873988565492933139831434890805700606251666;
    
    uint256 constant IC26x = 12876409352539679482180750741980239561437025832401175880076905684731927896206;
    uint256 constant IC26y = 14960884975197441942193471628236612513969009159476770515545914701168122214343;
    
 
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
