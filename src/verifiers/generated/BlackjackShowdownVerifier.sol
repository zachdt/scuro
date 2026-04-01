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

contract BlackjackShowdownVerifier {
    // Scalar field size
    uint256 constant r    = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
    // Base field size
    uint256 constant q   = 21888242871839275222246405745257275088696311157297823662689037894645226208583;

    // Verification Key data
    uint256 constant alphax  = 6530031235970850283118747997155835089086874891103647013468650848130351743056;
    uint256 constant alphay  = 14840637107003363705773497300093829614900578136420337723549337162204639783541;
    uint256 constant betax1  = 17247215301088280390075191565452565046635324041707079833590260512299647583385;
    uint256 constant betax2  = 2675519603970126215148881275746231032575992266401088432208313230986695905504;
    uint256 constant betay1  = 12427696260948033485744702735901884640050850503006522394213692126384974234633;
    uint256 constant betay2  = 4357533812966687642862183985066539845550557616324311925176426570981457287077;
    uint256 constant gammax1 = 11559732032986387107991004021392285783925812861821192530917403151452391805634;
    uint256 constant gammax2 = 10857046999023057135944570762232829481370756359578518086990519993285655852781;
    uint256 constant gammay1 = 4082367875863433681332203403145435568316851327593401208105741076214120093531;
    uint256 constant gammay2 = 8495653923123431417604973247489272438418190587263600148770280649306958101930;
    uint256 constant deltax1 = 6977283565002126681847679191115858069038108477043862638148264194412431390760;
    uint256 constant deltax2 = 15905911715047046556311431903803915995760596205913263933199084174699649237488;
    uint256 constant deltay1 = 18030068943069296518125771728246939535839541813868733399142108088593153580740;
    uint256 constant deltay2 = 11795446300656992813017773223798818570869842391470267747940905292985035870840;

    
    uint256 constant IC0x = 19311204913841069037709838628583745108890607380111764162323162656016646480574;
    uint256 constant IC0y = 7336829111197515576920781454555214012009203131879599510227718025580551902543;
    
    uint256 constant IC1x = 14040177263010867980561920754070511240404128077074500816801312633127851852471;
    uint256 constant IC1y = 8966549256182337803216010809255234381722329291214690170780874383156805461571;
    
    uint256 constant IC2x = 17247566126008831686254778613777665078683904454795592560305889864910819003182;
    uint256 constant IC2y = 1925152638729680079851740292384457935326847367397693263916559350237061805602;
    
    uint256 constant IC3x = 10557029519780196157469157853279794634710993998614945678387636079558388108752;
    uint256 constant IC3y = 7141459305362739643974460352017294907490610701450275822940385453506784425598;
    
    uint256 constant IC4x = 4449698933246248029553644406426647005352576016628238971169696360606519451406;
    uint256 constant IC4y = 8177463498529246835558958039427899916341841010285040108245656718149753404683;
    
    uint256 constant IC5x = 2532262606996380478640521210076842128795936785878698063109613948904431325460;
    uint256 constant IC5y = 11262834888825109452696830443804037380536464271331838248843684108294026378683;
    
    uint256 constant IC6x = 20109145238473315750809984586673224673080708395447571792132506916427564839358;
    uint256 constant IC6y = 21540736560407744870317753249144729202089629079121695355613261340796831677799;
    
    uint256 constant IC7x = 21271487056270148233441999647412808806179837059446615714008360602570369031428;
    uint256 constant IC7y = 14978024952431194428295189169250973318979581725011389929109075823012694834834;
    
    uint256 constant IC8x = 17020366203581224099370750804042860152855471726196543216059390208653816797023;
    uint256 constant IC8y = 9418492620453047093028690654607770317949392900637419762672440015728660057468;
    
    uint256 constant IC9x = 20921461390167390086594675519126886944093687136159366547032264201535653993107;
    uint256 constant IC9y = 289449566296208223558341246835194207476168458273752302709063844715889319520;
    
    uint256 constant IC10x = 3513123468418522025896324657858269057477350688465275481469922220380018146853;
    uint256 constant IC10y = 14397518561882120919893437258477858299231967366237484612976580841644222272974;
    
    uint256 constant IC11x = 15890852293267234618130989154653778879096364480660533314304617842355401251840;
    uint256 constant IC11y = 11564309742295066428917522989733329245604100693099004337729109925284397446808;
    
    uint256 constant IC12x = 15477641083245318503124430328018341832680611155288275900603466598825627254175;
    uint256 constant IC12y = 9078052761273586314389891163940359697293731855456267185379923904174490122532;
    
    uint256 constant IC13x = 18106179150358772333231547489129590183525735616322937894885548135278528392417;
    uint256 constant IC13y = 16987115497788566598264793851022168109545400452970404520394151593485970366086;
    
    uint256 constant IC14x = 17833509580229160715447608945821606749158925856121627973279204439120195542761;
    uint256 constant IC14y = 11490126090440960087744806131960775672618667355465284650377347848143260325846;
    
    uint256 constant IC15x = 14191288299813535113581347848229861446229067844121637624716563438842892467034;
    uint256 constant IC15y = 10054074181891834342801632827668116521151912400632431378083199815737731736566;
    
    uint256 constant IC16x = 8137596203301826067346665495890997681802052361632531380188262687364664945244;
    uint256 constant IC16y = 5903546884320781403222472493958996073429000494627865522164625270565592916841;
    
    uint256 constant IC17x = 15962309482551763180246478554950024875420586695544175127021099370625886508733;
    uint256 constant IC17y = 17043317278790594711057061325760056374549461266895422793382393655675518509297;
    
    uint256 constant IC18x = 16518796892501045083778275754836148191426791623922505244130961471884114597657;
    uint256 constant IC18y = 10017571861319288829656327051239741482128931311049112279847718562477842654142;
    
    uint256 constant IC19x = 1850117477925254354617192846920453455946564827585297192963207526793435634718;
    uint256 constant IC19y = 6326753959783346917829242090177127689749311504486912851159190543979045776828;
    
    uint256 constant IC20x = 20740750005478219930864959210794132647888876101218816708871364388203226061491;
    uint256 constant IC20y = 871291448087595881947378577844335650547295331825337686170563185718926059321;
    
    uint256 constant IC21x = 2705851495640606793648027696303934965189214283886745828792355495702112716066;
    uint256 constant IC21y = 14383942520088967413174140549366064270999831386693928600149199503080474716546;
    
    uint256 constant IC22x = 1228120932672244307507126834534806467942486998851343175728040872014103481335;
    uint256 constant IC22y = 4121597245217305111110305411320137610226292491460716710056734138338515384443;
    
    uint256 constant IC23x = 5950312720121660741832520710041828531146217046178180532364033112948397849105;
    uint256 constant IC23y = 12997533622848795982540123067908699836100232254159823984714997817514631353111;
    
    uint256 constant IC24x = 12865966771382878966999315251744055922673079999620657634909670685541540192383;
    uint256 constant IC24y = 13576188155823357227944662937311296559955959645808029651346867361114005150919;
    
    uint256 constant IC25x = 10479879734564804933535576231758302359271339590524155118158611701081710461298;
    uint256 constant IC25y = 14250105508065477576608790215452502204349063374072591641484927768258556202304;
    
    uint256 constant IC26x = 5660360580158798200348832925059499034213775388570161267126178816722668961632;
    uint256 constant IC26y = 14936714345508878310478738564349564512731776591702053729875652579348588295357;
    
    uint256 constant IC27x = 1712698304422922072229716132308053462247577583180746472865588373974389835787;
    uint256 constant IC27y = 2500183433543273380905777438424145513008455567172982865956991878335060955784;
    
    uint256 constant IC28x = 14650299070667816667688810672641940329916765184110497717619128617411140295465;
    uint256 constant IC28y = 11987100471230470997644376364722881606749706753830092824860201920776150167208;
    
    uint256 constant IC29x = 8973669582582863231560839550849636596944628595425161986106190167224341644463;
    uint256 constant IC29y = 2302331239681990133876122497531832306686267408305501986925075107570879496673;
    
    uint256 constant IC30x = 3431845229808593021519647299239319830747287406831212720592286291927578548755;
    uint256 constant IC30y = 6883289196116600708839929512125464525711942852835250008774155096569379183539;
    
    uint256 constant IC31x = 15800435041095770274551012050671976287917238517227639661939511462548138896995;
    uint256 constant IC31y = 18872539699176103937852186241932482826875840577344001815605014225060918275888;
    
    uint256 constant IC32x = 4336493338350938010363541943063090960589622658692695039928107267197161439742;
    uint256 constant IC32y = 20328557038779167570197075374981061155802489815827538502461005472008264089723;
    
    uint256 constant IC33x = 12839223500682558170793501350994719635899110395778583657176362827511124341926;
    uint256 constant IC33y = 14512071294757165392118131848975367413490134667643380527548430508348897211968;
    
    uint256 constant IC34x = 16674551179366098264567865013771862495274632900180112566289193010555158344403;
    uint256 constant IC34y = 12475916715972095353947348871971791949712688837127277825288812875791007652474;
    
    uint256 constant IC35x = 16903822133997943727848267088766652340644051218613927748529979252405831902140;
    uint256 constant IC35y = 18275727903989818851241164182676204605934249829622830793015212865834145421789;
    
    uint256 constant IC36x = 1494164018803733780868305219368686292784713610006100588964386974314745742838;
    uint256 constant IC36y = 167126668635425308128842493233325449257738507690485391507397767893674023030;
    
    uint256 constant IC37x = 310010940033481162946666636340598101746420084078337439619695182059911405406;
    uint256 constant IC37y = 2421085677313794945558114015651502060386876608739612696773456973449079127536;
    
    uint256 constant IC38x = 5184596062512020682836441295444727834952580922533868529843443715509800994701;
    uint256 constant IC38y = 8833632423157610035973095551184310371442696106989264534119979632872644697212;
    
    uint256 constant IC39x = 14163746797937067115284266675789734140707652128509320443039797409164717619144;
    uint256 constant IC39y = 5532624758301182786727594065015870431970429031519319589000213914225919696952;
    
    uint256 constant IC40x = 19851257148261736621125718896796606625240332420226016862780673388368833003641;
    uint256 constant IC40y = 3274359705355788859249603256865674753344519130049317384454327727621252288740;
    
    uint256 constant IC41x = 13594696758517232719813639312742282620695521929438991556991879326954800126247;
    uint256 constant IC41y = 18936343326311510179461469276375053403037608036782058123902355568597908837597;
    
 
    // Memory data
    uint16 constant pVk = 0;
    uint16 constant pPairing = 128;

    uint16 constant pLastMem = 896;

    function verifyProof(uint[2] calldata _pA, uint[2][2] calldata _pB, uint[2] calldata _pC, uint[41] calldata _pubSignals) public view returns (bool) {
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
                
                g1_mulAccC(_pVk, IC27x, IC27y, calldataload(add(pubSignals, 832)))
                
                g1_mulAccC(_pVk, IC28x, IC28y, calldataload(add(pubSignals, 864)))
                
                g1_mulAccC(_pVk, IC29x, IC29y, calldataload(add(pubSignals, 896)))
                
                g1_mulAccC(_pVk, IC30x, IC30y, calldataload(add(pubSignals, 928)))
                
                g1_mulAccC(_pVk, IC31x, IC31y, calldataload(add(pubSignals, 960)))
                
                g1_mulAccC(_pVk, IC32x, IC32y, calldataload(add(pubSignals, 992)))
                
                g1_mulAccC(_pVk, IC33x, IC33y, calldataload(add(pubSignals, 1024)))
                
                g1_mulAccC(_pVk, IC34x, IC34y, calldataload(add(pubSignals, 1056)))
                
                g1_mulAccC(_pVk, IC35x, IC35y, calldataload(add(pubSignals, 1088)))
                
                g1_mulAccC(_pVk, IC36x, IC36y, calldataload(add(pubSignals, 1120)))
                
                g1_mulAccC(_pVk, IC37x, IC37y, calldataload(add(pubSignals, 1152)))
                
                g1_mulAccC(_pVk, IC38x, IC38y, calldataload(add(pubSignals, 1184)))
                
                g1_mulAccC(_pVk, IC39x, IC39y, calldataload(add(pubSignals, 1216)))
                
                g1_mulAccC(_pVk, IC40x, IC40y, calldataload(add(pubSignals, 1248)))
                
                g1_mulAccC(_pVk, IC41x, IC41y, calldataload(add(pubSignals, 1280)))
                

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
            
            checkField(calldataload(add(_pubSignals, 832)))
            
            checkField(calldataload(add(_pubSignals, 864)))
            
            checkField(calldataload(add(_pubSignals, 896)))
            
            checkField(calldataload(add(_pubSignals, 928)))
            
            checkField(calldataload(add(_pubSignals, 960)))
            
            checkField(calldataload(add(_pubSignals, 992)))
            
            checkField(calldataload(add(_pubSignals, 1024)))
            
            checkField(calldataload(add(_pubSignals, 1056)))
            
            checkField(calldataload(add(_pubSignals, 1088)))
            
            checkField(calldataload(add(_pubSignals, 1120)))
            
            checkField(calldataload(add(_pubSignals, 1152)))
            
            checkField(calldataload(add(_pubSignals, 1184)))
            
            checkField(calldataload(add(_pubSignals, 1216)))
            
            checkField(calldataload(add(_pubSignals, 1248)))
            
            checkField(calldataload(add(_pubSignals, 1280)))
            

            // Validate all evaluations
            let isValid := checkPairing(_pA, _pB, _pC, _pubSignals, pMem)

            mstore(0, isValid)
             return(0, 0x20)
         }
     }
 }
